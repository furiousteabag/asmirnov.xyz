---
title: Breaking down GPU VRAM consumption
date: 2023-12-26
---

**Highlight**: Check out my [GPU VRAM Calculator](https://vram.asmirnov.xyz/){target="\_blank"}

I've always been curious about the GPU VRAM required for training and fine-tuning transformer-based language models. What factors influence VRAM consumption? How does it vary with different model settings? I dug into the topic and conducted my own measurements.

Other great resources on this topic include [Stas Bekman's section](https://github.com/stas00/ml-engineering/blob/master/performance/software.md#anatomy-of-models-memory-usage){target="\_blank"} from his ML Engineering book, the core inspiration for [Hugging Face's model memory anatomy article](https://huggingface.co/docs/transformers/main/en/model_memory_anatomy#anatomy-of-models-memory){target="\_blank"}. Also, check out [Eleuther's blog](https://blog.eleuther.ai/transformer-math/#memory-requirements){target="\_blank"} which also covers compute costs.

Quick note: This post doesn't delve into the memory usage of quantized models and PEFT fine-tuning techniques like LoRA or QLoRA.

## Prerequisites for experiments

When we talk about RAM, we often use GB (10\*\*9 bytes) and GiB (2\*\*30 bytes) interchangeably. But in reality, we're dealing with GiB. Take the Nvidia 3090's "24 GB VRAM" – it's actually 24 GiB, or about 25.76 GB. To keep things clear, I'll stick with MiB and GiB.

To measure VRAM usage accurately, we need to delete the variable, run garbage collection, clear the CUDA cache, and then measure the VRAM difference. Here’s an example:

```python
x = torch.Tensor(4, 8192, 32000).cuda()
total_vram = get_vram()
del x; gc.collect(); torch.cuda.empty_cache()
x_vram = total_vram - get_vram()
# 4000 MiB
```

The [ipyexperiments](https://github.com/stas00/ipyexperiments) Python package automates this after each cell execution, which is pretty convenient.

Before assessing memory usage, it's important to perform warm-up steps, essentially running the same code twice, to load CUDA kernels that weren't loaded during the initial setup. Also, we should disable the [cache](https://huggingface.co/docs/transformers/main/en/model_doc/mistral#transformers.MistralConfig.use_cache){target="\_blank"} in the decoder, which is used during inference to prevent re-computation of hidden states ^[[What is the purpose of ‘use_cache’ in decoder? (discuss.huggingface.co)](https://discuss.huggingface.co/t/what-is-the-purpose-of-use-cache-in-decoder/958/2){target="\_blank"}].

## Mixed precision training

Understanding mixed precision training is key, as it's commonly used in pretraining and finetuning. Normally, model parameters are stored in float32 format, taking up 4 bytes per parameter. Mixed precision training uses float16, halving the calculation time and reducing the size of activations.

But why "mixed"? The training isn't entirely in half precision. Lower precision can lead to imprecise weight updates or even gradients turning to zero. So, in mixed precision training, the master copy of the weights is kept and updated in fp32, and before each forward pass, these weights are copied into fp16 format.

For a deeper dive into mixed precision, check out this [fast.ai documentation](https://docs.fast.ai/callback.fp16.html){target="\_blank"}, which includes a detailed illustration, and [Aleksey Bilogur's blog](https://residentmario.github.io/pytorch-training-performance-guide/mixed-precision.html#){target="\_blank"}, which offers practical PyTorch code examples.

## Handling multi-GPU scenarios

What if a model doesn't fit on a single GPU? There are two scenarios:

1. Inference: Use model parallelism to distribute layers across GPUs. This is done automatically in transformers with `device_map="auto"`. Learn more in the [accelerate docs](https://huggingface.co/docs/accelerate/main/en/concept_guides/big_model_inference){target="\_blank"}.
2. Training: Distribute layers, optimizer states, and gradients across GPUs. Depending on your setup, you might use different [DeepSpeed ZeRO stages](https://www.microsoft.com/en-us/research/blog/zero-deepspeed-new-system-optimizations-enable-training-models-with-over-100-billion-parameters/){target="\_blank"} or [FSDP](https://engineering.fb.com/2021/07/15/open-source/fsdp/){target="\_blank"} ^[[Introducing PyTorch Fully Sharded Data Parallel (FSDP) API (pytorch.org/blog)](https://pytorch.org/blog/introducing-pytorch-fully-sharded-data-parallel-api/){target="\_blank"}] for full sharding. The more you shard, the slower training will be because of a communication overhead. For a comparison of multi-GPU training approaches, check out [Hugging Face's documentation](https://huggingface.co/docs/transformers/main/en/perf_train_gpu_many){target="\_blank"}.

## Breaking down the components

Memory consumption consists of the following components:

<center>

|                  | Train | Inference |
| :--------------: | :---: | :-------: |
|   CUDA Kernels   |  ✅   |    ✅     |
|    Parameters    |  ✅   |    ✅     |
|   Activations    |  ✅   |    ✅     |
|    Gradients     |  ✅   |    ❌     |
| Optimizer States |  ✅   |    ❌     |
|     Outputs      |  ✅   |    ✅     |

</center>

An interesting aspect of PyTorch is its approach to memory allocation. Essentially, PyTorch rarely releases memory once it's been allocated. For instance, during the forward pass, activations are calculated and stored in memory. Even after these activations are no longer needed following the backward pass, the memory they occupy isn't released. This strategy is adopted to avoid the overhead associated with frequent memory allocation calls ^[[What exactly is occupying the GPU cache? (discuss.pytorch.org)](https://discuss.pytorch.org/t/what-exactly-is-occupying-the-gpu-cache/80645/2){target="\_blank"}].

### CUDA Kernels

Upon first using the GPU, CUDA kernels will allocate between 300 MiB to 2000 MiB. This can vary based on GPU, driver, and PyTorch versions. It could be measured by initializing any small tensor and moving it to GPU:

```python
x = torch.ones(1).cuda()
```

### Parameters

When measuring the amount of memory that will be used by parameters, it is important to understand the difference between parameters and buffers. Parameters are the actual weights that are being trained and updated by the optimizer. They could be retrieved by calling `model.parameters()`. Apart from parameters there exist fixed tensors, which are needed in some computations, but which are not needed to be updated. These are called buffers and may be retrieved by calling `model.buffers()`. One example of buffers is precomputed positional encodings ^[[What is the difference between `register_buffer` and `register_parameter` of `nn.Module` (discuss.pytorch.org)](https://discuss.pytorch.org/t/what-is-the-difference-between-register-buffer-and-register-parameter-of-nn-module/32723){target="\_blank"}]. So, in this section, under 'parameters' I assume 'parameters' + 'buffers'.

During inference, the memory needed for parameters is straightforward — it's just the number of parameters multiplied by the number of bytes per parameter. You are specifying the number of bytes per parameter when loading a model like `.from_pretrained(..., torch_dtype=torch.float16)`. For instance, a 7B-parameter model like Mistral, when loaded in half-precision (float16), would take 7.51 × 10\*\*9 × 2 bytes, equating to 14324 MiB.

When training as usual, in full precision, 4 bytes per parameter are occupied. Mixed precision training is more common though, in this case, we have to maintain both half precision (for forward pass, 2 bytes per param) and full precision model weights (for applying updates to them, 4 bytes per param), so in total it takes 6 bytes per param.

### Activations

'Activations' refer to the intermediate outputs essential for backpropagation. They are usually the memory bottleneck in transformer training, especially since their size scales quadratically with sequence length (we have to store the output of a `softmax(Q×K.T)` which has Batch Size × Number of Attention Heads × Sequence Length \*\* 2 shape). There are good estimations of activations size per layer in ["Reducing Activation Recomputation in Large Transformer Models"](https://arxiv.org/abs/2205.05198){target="\_blank"} paper in section 4.1 although for each model activations will differ. For example, in the mentioned paper they also count dropout masks whereas newer architectures like [Llama](https://github.com/facebookresearch/llama/blob/main/llama/model.py){target="\_blank"} don't use dropout at all.

During training, we store all layer activations for backprop, but in inference, we only keep the current (single) layer's activations.

We can reduce activations size on training in the cost of training speed (slowdown around 20%) by discarding the activations during the forward pass and recalculating them when needed during the backward pass, this is called [gradient checkpointing](https://medium.com/tensorflow/fitting-larger-networks-into-memory-583e3c758ff9){target="\_blank"}.

### Gradients

Gradients are always stored in full precision taking 4 bytes per parameter.

### Optimizer states

Optimizers like Adam and SGD have their own memory needs. SGD with momentum and Adam both store a moving average of gradients for each parameter in full precision. Additionally, Adam keeps a moving average of squared gradients.

<center>

|                | First Moments | Second Moments | Bytes per Param |
| :------------: | :-----------: | :------------: | :-------------: |
|      SGD       |      ❌       |       ❌       |        0        |
| SGD w momentum |      ✅       |       ❌       |        4        |
|      ADAM      |      ✅       |       ✅       |        8        |

</center>

### Outputs

Finally, the output tensors (Batch Size × Sequence Length × Vocabulary Size) are almost always in float32. This remains true even if the model was loaded in a lower precision because model itself casts outputs to float32 most of the time ^[[Llama 2 casts output tensor to float32 (github.com/facebookresearch/llama)](https://github.com/facebookresearch/llama/blob/main/llama/model.py#L494){target="\_blank"}] ^[[Mistral casts output tensor to float32 (github.com/mistralai)](https://github.com/mistralai/mistral-src/blob/main/mistral/model.py#L304){target="\_blank"}].

While training, we also need to store probabilities `F.softmax(logits, dim=-1)` which are the same size as the output tensor.

## Problems

In my experiments with measuring VRAM usage [in the notebook](https://github.com/furiousteabag/vram/blob/master/vram.ipynb){target="\_blank"}, I am facing some persistent mismatch between what my experiments show and the calculated figures, particularly regarding the size of activations during the training's forward pass. So there is still something to figure out!

## Acknowledgements

Thanks to [Stas Bekman](https://stasosphere.com/machine-learning/){target="\_blank"} for helping me shape my understanding and Quentin Anthony's Python [gist for VRAM calculation](https://gist.github.com/Quentin-Anthony/f43939791a7ceb0b01a4937308317be5){target="\_blank"}.
