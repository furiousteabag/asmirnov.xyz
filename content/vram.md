---
title: Breaking down GPU VRAM consumption
date: 1970-01-01
---

**Update**: Check out my [GPU VRAM Calculator](https://vram.asmirnov.xyz/)

I've always been curious about the GPU VRAM required for training and fine-tuning transformer-based language models. What factors influence VRAM consumption? How does it vary with different model settings? I dug into the topic and conducted my own measurements.

Other great resources on this topic include [Stas Bekman's section](https://github.com/stas00/ml-engineering/blob/master/performance/software.md#anatomy-of-models-memory-usage) from his ML Engineering book, the core inspiration for [Hugging Face's model memory anatomy article](https://huggingface.co/docs/transformers/main/en/model_memory_anatomy#anatomy-of-models-memory). Also, check out [Eleuther's blog](https://blog.eleuther.ai/transformer-math/#memory-requirements) which also covers compute costs.

Quick note: This post doesn't delve into memory usage of quantized models and PEFT fine-tuning techniques like LoRA or QLoRA.

## Prerequisites for experiments

When we talk about RAM, we often use GB (10\*\*9 bytes) and GiB (2\*\*30 bytes) interchangeably. But in reality, we're dealing with GiB. Take the Nvidia 3090's "24 GB VRAM" – it's actually 24 GiB, or about 25.76 GB. To keep things clear, I'll stick with MiB and GiB.

To measure VRAM usage accurately, we need to delete the variable, run garbage collection, clear CUDA cache, and then measure the VRAM difference. Here’s an example:

```python
x = torch.Tensor(4, 8192, 32000).cuda()
total_vram = get_vram()
del x; gc.collect(); torch.cuda.empty_cache()
x_vram = total_vram - get_vram()
# 4000 MiB
```

The [ipyexperiments](https://github.com/stas00/ipyexperiments) Python package automates this after each cell execution, which is pretty convenient.

Before assessing memory usage, it's essential to perform warm-up steps, essentially running the same code twice, to load CUDA kernels that weren't loaded during the initial setup. Also, we should disable the [cache](https://huggingface.co/docs/transformers/main/en/model_doc/mistral#transformers.MistralConfig.use_cache) in the decoder, which is used during inference to prevent re-computation of hidden states ^[[What is the purpose of ‘use_cache’ in decoder? (discuss.huggingface.co)](https://discuss.huggingface.co/t/what-is-the-purpose-of-use-cache-in-decoder/958/2)].

## Mixed precision training

Understanding mixed precision training is key, as it's commonly used in pretraining and finetuning. Normally, model parameters are stored in float32 format, taking up 4 bytes per parameter. Mixed precision training uses float16, halving the calculation time and reducing the size of activations.

But why "mixed"? The training isn't entirely in half precision. Lower precision can lead to imprecise weight updates or even gradients turning to zero. So, in mixed precision training, the master copy of the weights is kept and updated in fp32, and before each forward pass, these weights are copied into fp16 format.

For a deeper dive into mixed precision, check out this [fast.ai documentation](https://docs.fast.ai/callback.fp16.html), which includes a detailed illustration, and [Aleksey Bilogur's blog](https://residentmario.github.io/pytorch-training-performance-guide/mixed-precision.html#), which offers practical PyTorch code examples.

## Handling multi-GPU scenarios

What if a model doesn't fit on a single GPU? There are two scenarios:

1. Inference: Use model parallelism to distribute layers across GPUs. This is done automatically in transformers with `device_map="auto"`. Learn more in the [accelerate docs](https://huggingface.co/docs/accelerate/main/en/concept_guides/big_model_inference).
2. Training: Distribute layers, optimizer states and gradients across GPUs. Depending on your setup, you might use different [DeepSpeed ZeRO stages](https://www.microsoft.com/en-us/research/blog/zero-deepspeed-new-system-optimizations-enable-training-models-with-over-100-billion-parameters/) or [FSDP](https://engineering.fb.com/2021/07/15/open-source/fsdp/) ^[[Introducing PyTorch Fully Sharded Data Parallel (FSDP) API (pytorch.org/blog)](https://pytorch.org/blog/introducing-pytorch-fully-sharded-data-parallel-api/)] for full sharding. The more you shard, the slower training will be because of a communication overhead. For a comparison of multi-GPU training approaches, check out [Hugging Face's documentation](https://huggingface.co/docs/transformers/main/en/perf_train_gpu_many).
