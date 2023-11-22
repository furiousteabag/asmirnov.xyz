---
title: none
date: none
---

For most people I interact with, I'm just another text-based program for the most of the time. If input and output is so simple, could I be replaced by the model? For this to work, the model would need to not only understand my writing style but also know a lot about me. The best source for this is my Telegram messenger, as I use it daily and it contains almost everything about my thoughts and actions in the form of chat histories.

## Approach

The most straightforward approach would be to extract all my messages, load them into ChatGPT's context, and instruct it to use this information to mimic my style when responding to new messages. However, this approach is limited by the context window size, requiring me to preprocess messages to extract key points. As I want to avoid this hassle, perhaps Retrieval Augmented Generation (RAG) could be used to pull necessary information when needed. But from my experience, retrieving from diverse data like chat sessions usually needs a supervised fine-tuning of the retrieval model, and I'm not keen on creating such a dataset. So, fine-tuning seems like the best option. It's ideal for several reasons: it should capture my writing style and potentially accumulate knowledge from all my messages without having to select what's important.

OpenAI offers [fine-tuning capabilities](https://platform.openai.com/docs/guides/fine-tuning){target="\_blank"}, but as I'll be using my private messages, I'm not keen on using any third-party fine-tuning service. So, I need to choose a base model. According to the [Hugging Face Open LLM Leaderboard](https://huggingface.co/spaces/HuggingFaceH4/open_llm_leaderboard){target="\_blank"}, one of the top smaller models (≤13B parameters) is [Mistral 7B](https://huggingface.co/mistralai/Mistral-7B-v0.1){target="\_blank"}. It even outperforms [Llama 2 13B](https://huggingface.co/meta-llama/Llama-2-13b-hf){target="\_blank"}. Now, the question is whether [LoRA](https://arxiv.org/abs/2106.09685){target="\_blank"} is sufficient or if full fine-tuning is necessary. Various comparisons ^[[Fine-Tuning LLMs: LoRA or Full-Parameter? An in-depth Analysis with Llama 2 (anyscale.com/blog)](https://www.anyscale.com/blog/fine-tuning-llms-lora-or-full-parameter-an-in-depth-analysis-with-llama-2){target="\_blank"}] ^[[LoRA results in 4-6% lower performance compared to full fine-tuning (github.com/huggingface/peft/issues)](https://github.com/huggingface/peft/issues/622){target="\_blank"}] suggests that LoRA is a bit worse than full fine-tuning but still fine most of the time. However, for specific tasks like mine (Russian language + chat), I found a [paper](https://arxiv.org/abs/2304.08109){target="\_blank"}, where researchers conducted Llama instruction fine-tuning in Chinese, similar in complexity to my goal. They found that LoRA-based tuning on a base model without prior instruction tuning is less effective than full fine-tuning. Yet, LoRA-based tuning on a model already fine-tuned for instructions can yield comparable results. For my case, this means either full fine-tuning on a base model or LoRA on a model already fine-tuned for chatting in Russian. Since I couldn't find a model fine-tuned for Russian chat, I'll try LoRA on a model fine-tuned for English chat, like the fine-tuned Mistral model [Dolphin](https://huggingface.co/ehartford/dolphin-2.2.1-mistral-7b){target="\_blank"}.

So, the plan is:

1. Start with LoRA on top of Dolphin, the English chat fine-tuned Mistral
2. If quality not sufficient, try full fine-tune on Mistral

## Data preparation

One unique aspect of messaging in apps like Telegram, compared to emails, is the conversational flow. Messages don't usually alternate one-by-one between you and your contact. Instead, you often find yourself sending a couple of messages in a row, followed by several responses from the other person. These messages are generally short, too. I wanted to preserve this natural conversational style in my data.

Telegram offers a [built-in feature](https://telegram.org/blog/export-and-more){target="\_blank"} to export all chats into JSON. After some filtering and grouping messages into sessions, I've compiled data from the last two years of using Telegram. This resulted in 7,851 sessions from 317 chats, with an average session length of 8.7 messages. For structuring the data, I've chosen the [ChatML](https://github.com/openai/openai-python/blob/284c1799070c723c6a553337134148a7ab088dd8/chatml.md){target="\_blank"} prompt format. Here’s a sample session (translated from Russian):

<|im_start|>John Smith<br />
**>>> damn, can't get around the 135 time limit**<br />
**>>> trying to do everything super optimally, but no luck<|im_end|>**<br />
<|im_start|>Alexander Smirnov<br />
**>>> yeah same**<br />
**>>> you still going with the same idea?<|im_end|>**<br />
<|im_start|>John Smith<br />
**>>> dunno, I think we're on the same page**<br />
**>>> as you said**<br />
**>>> going with the reversed string in a try and trying to find something there**<br />
**>>> seems like real shit because z function ruins everything........................<|im_end|>**<br />
<|im_start|>Alexander Smirnov<br />
**>>> don't get where z comes into this<|im_end|>**<br />
<|im_start|>John Smith<br />
**>>> dunno seems like I'm doing everything iteratively anyway, but yeah gotta reverse some strings to build the z function**<br />
**>>> and it's just a random solution**<br />
**>>> from discussions<|im_end|>**<br />
<|im_start|>Alexander Smirnov<br />
**>>> got it<|im_end|>**<br />

<details>
    <summary>original</summary>
    <|im_start|>Иван Иванович<br />
    **>>> бля не могу обойти таймлим на 135**<br />
    **>>> пытаюсь все супер оптимально делать, но хуйтам)<|im_end|>**<br />
    <|im_start|>Alexander Smirnov<br />
    **>>> да вот жиза**<br />
    **>>> ты с той же идеей?<|im_end|>**<br />
    <|im_start|>Иван Иванович<br />
    **>>> да хз, думаю у нас одно и тоже**<br />
    **>>> как ты сказал**<br />
    **>>> иду с реверснутой строкой в трай и чето пытаюсь там найти**<br />
    **>>> походу реальная параша на z функции все руинит........................<|im_end|>**<br />
    <|im_start|>Alexander Smirnov<br />
    **>>> не пон где тут про z<|im_end|>**<br />
    <|im_start|>Иван Иванович<br />
    **>>> хз вроде все итеративно итак делаю, ну да кое где надо реверснуть строки чтобы з функцию построить**<br />
    **>>> а это просто рандомное решение**<br />
    **>>> с дискашенов<|im_end|>**<br />
    <|im_start|>Alexander Smirnov<br />
    **>>> пон<|im_end|>**<br />
</details>

My data collator ensures that the loss is only calculated based on someone's response. Predicting who will speak next is relatively straightforward, and we don't want the model to focus on learning that. Therefore, parts of the conversation where the loss is calculated are highlighted in bold.

You might notice that not only my responses but also those of others are used for loss calculation. This is deliberate. By doing this, the model will be able to role-play not only as me but also as my frequent conversational partners!
