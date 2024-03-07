---
title: Learnings from fine-tuning LLM on my Telegram messages
date: 2023-11-27
---

**Highlight**: Check out [HN discussion of this post](https://news.ycombinator.com/item?id=38434914){target="\_blank"}

For most people I interact with, I'm just another text-based program for the most of the time. If input and output are so simple, could I be replaced by the model? For this to work, the model would need to not only understand my writing style but also know a lot about me. The best source for this is my Telegram messenger, as I use it daily and it contains almost everything about my thoughts and actions in the form of chat histories.

## Approach

The most straightforward approach would be to extract all my messages, load them into ChatGPT's context, and instruct it to use this information to mimic my style when responding to new messages. However, this approach is limited by the context window size, requiring me to preprocess messages to extract key points. As I want to avoid this hassle, perhaps Retrieval Augmented Generation (RAG) could be used to pull necessary information when needed. However from my experience, retrieving from diverse data like chat sessions usually needs a supervised fine-tuning of the retrieval model, and I'm not keen on creating such a dataset. So, fine-tuning seems like the best option. It's ideal for several reasons: it should capture my writing style and potentially accumulate knowledge from all my messages without having to select what's important.

OpenAI offers [fine-tuning capabilities](https://platform.openai.com/docs/guides/fine-tuning){target="\_blank"}, but as I'll be using my private messages, I don't want to use any third-party fine-tuning services. So, I need to choose a base model. According to the [Hugging Face Open LLM Leaderboard](https://huggingface.co/spaces/HuggingFaceH4/open_llm_leaderboard){target="\_blank"}, one of the top smaller models (≤13B parameters) is [Mistral 7B](https://huggingface.co/mistralai/Mistral-7B-v0.1){target="\_blank"}. It even outperforms [Llama 2 13B](https://huggingface.co/meta-llama/Llama-2-13b-hf){target="\_blank"}. Now, the question is whether [LoRA](https://arxiv.org/abs/2106.09685){target="\_blank"} is sufficient or if full fine-tuning is necessary. Various comparisons ^[[Fine-Tuning LLMs: LoRA or Full-Parameter? An in-depth Analysis with Llama 2 (anyscale.com/blog)](https://www.anyscale.com/blog/fine-tuning-llms-lora-or-full-parameter-an-in-depth-analysis-with-llama-2){target="\_blank"}] ^[[LoRA results in 4-6% lower performance compared to full fine-tuning (github.com/huggingface)](https://github.com/huggingface/peft/issues/622){target="\_blank"}] suggests that LoRA is a bit worse than full fine-tuning but still fine most of the time. However, for specific tasks like mine (Russian language + chat), I found a [paper](https://arxiv.org/abs/2304.08109){target="\_blank"}, where researchers conducted Llama instruction fine-tuning in Chinese, similar in complexity to my goal. They found that LoRA-based tuning on a base model without prior instruction tuning is less effective than full fine-tuning. Yet, LoRA-based tuning on a model already fine-tuned for instructions can yield comparable results. In my case, this means either full fine-tuning on a base model or LoRA on a model already fine-tuned for chatting in Russian. Since I couldn't find a model fine-tuned for Russian chat, I'll try LoRA on a model fine-tuned for English chat, like the fine-tuned Mistral model [Dolphin](https://huggingface.co/ehartford/dolphin-2.2.1-mistral-7b){target="\_blank"}.

So, the plan is:

1. Start with LoRA on top of Dolphin, the English chat fine-tuned Mistral
2. If quality is not sufficient, try full fine-tuning on Mistral

## Data preparation

One unique aspect of messaging in apps like Telegram, compared to emails, is the conversational flow. Messages don't usually alternate one-by-one between you and your contact. Instead, you often find yourself sending a couple of messages in a row, followed by several responses from the other person. These messages are generally short, too. I wanted to preserve this natural conversational style in my data.

Telegram offers a [built-in feature](https://telegram.org/blog/export-and-more){target="\_blank"} to export all chats into JSON. After some filtering and grouping messages into sessions, I've compiled data from the last five years of using Telegram. This resulted in 15,789 sessions from 466 chats, with an average session length of 8.51 messages. For structuring the data, I've chosen the [ChatML](https://github.com/openai/openai-python/blob/284c1799070c723c6a553337134148a7ab088dd8/chatml.md){target="\_blank"} prompt format. Here’s a sample session (translated from Russian):

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

## Evaluation plan

I will test models by having chats in two ways. First, the model will pretend to be me and I will be chatting with myself from the perspective of my different friends. Then, I'll chat as myself while the model acts as my friends. My conversation starter will always be the same 2 messages: "hey" and "what's up?" (in Russian, "прив" and "как дела?"). Generated phrases and persons as the model acts who from will be **highlighted**. All conversations initially will be held in Russian and may be accessed by clicking on the 'original' details button. For testing I will be using [oobabooga/text-generation-webui](https://github.com/oobabooga/text-generation-webui){target="\_blank"}.

In the beginning, I want to explore how the generic conversation fine-tuned Mistral model deals with that task without any prior training from my side.

\-\-\-

<details>
    <summary>Friend 1 vs **Alexander Smirnov**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> I'm good, what about you?**<br />
    \>\>\> nothing much<br />
    \>\>\> what did you do today?<br />
    **>>> I worked.**<br />
    **>>> then I did a few tasks in Python and studied data processing libraries.**<br />
    **>>> in the evening I'll do wrestling training.**<br />
    **>>> have you ever been into sports or do you have any hobbies?**<br />
    \>\>\> I see<br />
    \>\>\> want to watch a movie today?<br />
    **>>> maybe, if I find the time.**<br />
    **>>> what's your favorite music? Electronic, rock, or other genres?**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> все хорошо, а у тебя что нового?**<br />
    \>\>\> да ничего<br />
    \>\>\> чего сегодня делал?<br />
    **>>> я работал.**<br />
    **>>> потом сделал несколько задач на python и изучал библиотеки для обработки данных.**<br />
    **>>> в вечер займусь тренировкой на борцу.**<br />
    **>>> ты когда-нибудь занимаешься спортом или имеешь какое-то хобби?**<br />
    \>\>\> понятно<br />
    \>\>\> посмотрим кино сегодня?<br />
    **>>> может быть, если найдется время.**<br />
    **>>> какая ваша любимая музыка? Электронная музыка, рок или другие жанры?**

</details>

\-\-\-

<details>
    <summary>Alexander Smirnov vs **Friend 1**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> well, everything is fine so far. what's new with you?**<br />
    >>> spent the whole day programming<br />
    >>> what did you do today?<br />
    **>>> finished at work**<br />
    **>>> and did some housework, now I'm resting. are you also resting or still working?**<br />
    >>> I'm already resting<br />
    **>>> well, that's good. can we talk about something interesting or do you have any questions?**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> ну пока все нормально. а у вас что нового?**<br />
    \>\>\> прогал целый день<br />
    \>\>\> чего сегодня делала?<br />
    **>>> закончила на работе**<br />
    **>>> и сделала немного домашней работы, теперь отдыхаю. а вы тоже отдохните или еще работаете?**<br />
    \>\>\> я уже отдыхаю<br />
    **>>> ну хорошо. можно поговорить о чем-нибудь интересном или вы имеете какие-то вопросы?**

</details>

\-\-\-

Ok, it is capable of forming coherent sentences. The most noticeable problem is its lack of awareness regarding the context of the conversations which leads to bland and generic replies. The messages lacked any distinct style, feeling quite basic. Another issue is that the model's Russian is poor. This is expected, as the model is too small to generalize well to languages other than its primary one, English. Additionally, the model tended to be overly proactive, ending almost every sentence with a question, which isn't how real people typically communicate in messengers.

Let's try to fix all of these!

## LoRA

LoRA offers a low-effort approach in terms of both the training pipeline and hardware requirements. It trains around 1% of the total weights. I chose a 1024 sequence length and a batch size of 8. The training, which consumed 20GB of VRAM on an RTX 3090, took three epochs and lasted for 5.5 hours. For this, I used [vast.ai](https://vast.ai/){target="\_blank"}, where the GPU cost was $0.362 per hour, totaling $2 for the entire training, excluding time spent on experiments and bug fixes.

Here are the results:

\-\-\-

<details>
    <summary>Friend 1 vs **Alexander Smirnov**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> hi) all good**<br />
    **>>> you?)**<br />
    \>\>\> ok as well<br />
    \>\>\> what you were doing today?<br />
    **>>> had an amazon interview and solved problems**<br />
    **>>> had to solve 3**<br />
    \>\>\> cool<br />
    \>\>\> hard?<br />
    **>>> don't know what**<br />
    **>>> hadn't looked yet**<br />
    **>>> I hadn't started yet**<br />
    **>>> chatting whole day with the team and meet new ones**<br />
    \>\>\> how are they?<br />
    **>>> ok**<br />
    **>>> same coworking as you have))**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> Привет) нолм все**<br />
    **>>> ты как?)**<br />
    \>\>\> да тоже норм<br />
    \>\>\> чего делал сегодня?<br />
    **>>> собесился в амазон и решал задачки**<br />
    **>>> надо было 3 прорешить**<br />
    \>\>\> прикольно<br />
    \>\>\> сложные?<br />
    **>>> хз какие**<br />
    **>>> пока не смотрел**<br />
    **>>> я еще ничего не началь**<br />
    **>>> весь день просто болтаю с людьми из команды и встречаю новых**<br />
    \>\>\> как ребята?<br />
    **>>> норм**<br />
    **>>> такой же ковер как у тебя))**

</details>

\-\-\-

<details>
    <summary>Friend 2 vs **Alexander Smirnov**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> ok, we show yesterday's product to searchcom, today we write endpoints for them so that someone else can request our api**<br />
    \>\>\> cool<br />
    \>\>\> what problems do we have now?<br />
    **>>> no problems**<br />
    **>>> everything is working**<br />
    **>>> I added an option to choose index**<br />
    **>>> so now we can attach several indexes**<br />
    **>>> and separate collections within single index**<br />
    \>\>\> what we have to do?<br />
    **>>> test**<br />
    **>>> yes ok**<br />
    **>>> are they always will be sending post-script?**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> хорошо, показываем вчерашний продукт ищком, сегодня пилим эндпоинты для них чтобы кто-то еще мог нашу апи запросить**<br />
    \>\>\> найс<br />
    \>\>\> какие сейчас есть проблемы?<br />
    **>>> нет проблем**<br />
    **>>> все работает**<br />
    **>>> я добавил опцию выбора индекса**<br />
    **>>> так что теперь уже можно несколько индексов подключить**<br />
    **>>> и отдельные коллекции внутри одного индекса**<br />
    \>\>\> что надо сделать?<br />
    **>>> протестировать**<br />
    **>>> ага норм**<br />
    **>>> а точно они всегда пост-скрипт будут кидать?**

</details>

\-\-\-

<details>
    <summary>Friend 3 vs **Alexander Smirnov**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> Hi, good)**<br />
    **>>> you?**<br />
    \>\>\> ok as well<br />
    \>\>\> what do you do at the evening?<br />
    **>>> we have meeting with office collegues at 8 30 msk**<br />
    **>>> after it I can**<br />
    \>\>\> can what?<br />
    **>>> haha)**<br />
    \>\>\> didn't get it<br />
    **>>> I don't know(**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> Привет, хорошо)**<br />
    **>>> ты?**<br />
    \>\>\> да тоже норм<br />
    \>\>\> что делаешь вечером?<br />
    **>>> у нас с колегами встреча по офису в 8 30 мск**<br />
    **>>> после нее я могу**<br />
    \>\>\> можешь что?<br />
    **>>> ахах)**<br />
    \>\>\> не понял<br />
    **>>> я не знаю(**

</details>

\-\-\-

<details>
    <summary>Alexander Smirnov vs **Friend 1**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> hi)**<br />
    **>>> seems good**<br />
    **>>> was working, than went to the call with Nadya**<br />
    **>>> now reading normally**<br />
    **>>> you?**<br />
    \>\>\> good as well<br />
    \>\>\> any plans for the evening?<br />
    **>>> after work wendesday I would love to go running**<br />
    **>>> and then have a lunch**<br />
    **>>> your plans?**<br />
    \>\>\> I though about watching movie<br />
    **>>> aa**<br />
    **>>> ooo**<br />
    **>>> to be honest I like when it is raining**<br />
    **>>> when you don't feel like going anywhere**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> привет)**<br />
    **>>> вроде хорошо**<br />
    **>>> поработал, затем поехал на коле с Надей**<br />
    **>>> сейчас читаю нормально**<br />
    **>>> а ты как?**<br />
    \>\>\> да тоже хорошо<br />
    \>\>\> какие планы на вечер?<br />
    **>>> мне после работы среда хотелось бы сходить на пробежку**<br />
    **>>> а потом ужинать**<br />
    **>>> а что твои планы?**<br />
    \>\>\> я думал кино посмотреть<br />
    **>>> аа**<br />
    **>>> ооо**<br />
    **>>> честно говоря мне нравится теплый дождь больше всего**<br />
    **>>> когда так не хочется никуда идти**

</details>

\-\-\-

<details>
    <summary>Alexander Smirnov vs **Friend 2**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> Hi, great!**<br />
    **>>> Sorry will be 20-30 min late**<br />
    \>\>\> ok<br />
    \>\>\> why?<br />
    **>>> yes, I just got up and forgot to press the «exit sleep» button**<br />
    **>>> my telegram didn’t close on its own**<br />
    **>>> I thought it behaved like this when you logging off the Internet, but no**<br />
    **>>> I still logged off the Internet, but telegram still didn't respond**<br />
    **>>> and it was strange, because yesterday there was also such a case when I sent you a message and did not receive an answer**<br />
    **>>> today I looked at mine, but not yours, but yours was displayed)**<br />
    \>\>\> ok<br />
    \>\>\> any plans?<br />
    **>>> yes, we can chat a little**<br />
    **>>> and I can tell you that the method for generating answers worked really well for me**<br />
    **>>> he gives respectable results in training**<br />
    **>>> but not on the test**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> Привет, хорошо!**<br />
    **>>> Соре опаздываю еще минут 20-30**<br />
    \>\>\> пон<br />
    \>\>\> а чего так?<br />
    **>>> да я просто встал и забыл нажать кнопку «выйти из сна»**<br />
    **>>> у меня телега сама не закрылась**<br />
    **>>> я думал она так себя ведёт, когда ты выходишь из интернета, но вот**<br />
    **>>> я все таки вышел из интернета, но телега все равно не отвечает**<br />
    **>>> и это странно было, потому что вчера тоже был такой случай, когда я отправил тебе сообщение и не получал ответа**<br />
    **>>> сегодня же я посмотрел свое, но не твоё, а твое отобразилось)**<br />
    \>\>\> окей<br />
    \>\>\> какие планы?<br />
    **>>> да можно чуть поболтать**<br />
    **>>> и можно рассказать что у меня прям очень сильно заработал метод по генерации ответов**<br />
    **>>> он на тренировках дает респектабельные результаты**<br />
    **>>> но не на тесте**

</details>

\-\-\-

<details>
    <summary>Alexander Smirnov vs **Friend 3**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> hey, hi**<br />
    **>>> Good, you?)**<br />
    **>>> Haven’t gone to bed yet)0)0)0)**<br />
    **>>> Today I get up and go to a programming course**<br />
    **>>> To tighten up the base, etc.**<br />
    \>\>\> nice<br />
    \>\>\> what did you do yesterday?<br />
    **>>> Yesterday there was already the same course in which it seemed to me that I did very poorly**<br />
    **>>> Then I wanted to solve hw but I don’t care**<br />
    **>>> Otherwise I’m fucked because I can’t sleep)**<br />
    **>>> Really fucked up**<br />
    **>>> It will probably be better now, since I’m already maximally overtrained**<br />
    \>\>\> cool man<br />
    \>\>\> what are your plans for life in general?<br />
    **>>> Fuck, get a job interviews first**<br />
    **>>> And if everything is ok, then actually order a computer**<br />
    **>>> Like, I think you should order a computer when it’s more profitable than working at work**<br />
    **>>> But I don't care**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> Прив, дароу**<br />
    **>>> Норм, ты как?)**<br />
    **>>> Еще спать не зашел)0)0)0)**<br />
    **>>> Сегодня встаю и еду на курс по програмированию**<br />
    **>>> Чтоб базу подтянуть и тд**<br />
    \>\>\> найс<br />
    \>\>\> че вчера делал?<br />
    **>>> Вчера уже был такой же курс в котором мне казалось что я оч плохо провел**<br />
    **>>> Потом хотел порешать дз но пофиг**<br />
    **>>> А то заебался из-за того что спать не могу)**<br />
    **>>> Прям пиздец**<br />
    **>>> Наверное сейчас будет лучше, так как уже максимально переобуженный**<br />
    \>\>\> слушай ну с кайфом<br />
    \>\>\> какие планы вообще на жизнь?<br />
    **>>> Бля, тупо сначала собеситься на работу**<br />
    **>>> И если все ок то реально заказать комп**<br />
    **>>> Типо я думаю надо было бы заказывать комп когда выигральнее чем на работе работаешь**<br />
    **>>> Но я хз**

</details>

\-\-\-

This is much better. It definitely captures the style of the person it's responding on behalf of. It also identifies the most common topics discussed between specific pairs of people. For example, with friend 2, the focus is clearly more on work. However, the grammar is still off, and it loses the context of the conversation quickly. I'm pretty confident that LoRA would work with reasonable quality in English, and full fine-tuning might not be necessary. But, since Russian isn't the model's native language, let's try full fine-tuning.

## Full fine-tuning

Full fine-tuning is more challenging due to the need for multi-GPU training. Popular methods include either [ZeRO & DeepSpeed](https://www.microsoft.com/en-us/research/blog/zero-deepspeed-new-system-optimizations-enable-training-models-with-over-100-billion-parameters/){target="\_blank"} ^[[How to Choose Which ZeRO Stage and Offloads To Use For Best Performance (huggingface.co/docs)](https://huggingface.co/docs/transformers/main_classes/deepspeed#how-to-choose-which-zero-stage-and-offloads-to-use-for-best-performance){target="\_blank"}] or [FSDP](https://engineering.fb.com/2021/07/15/open-source/fsdp/){target="\_blank"} ^[[Introducing PyTorch Fully Sharded Data Parallel (FSDP) API (pytorch.org/blog)](https://pytorch.org/blog/introducing-pytorch-fully-sharded-data-parallel-api/){target="\_blank"}], with FSDP essentially being a ZeRO3 ^[[It’s 2023. Is PyTorch’s FSDP the best choice for training large models? (openmmlab.medium.com)](https://openmmlab.medium.com/its-2023-is-pytorch-s-fsdp-the-best-choice-for-training-large-models-fe8d2848832f){target="\_blank"}]. I decided to go with FSDP.

While implementing the training pipeline, I referred to the [Stanford Alpaca fine-tuning code](https://github.com/tatsu-lab/stanford_alpaca/){target="\_blank"} and [Anton Bacaj's Mistral fine-tuning code](https://github.com/abacaj/fine-tune-mistral/){target="\_blank"}.

Using a half-precision FSDP full shard with a 1024 sequence length and a micro batch size of 2 required 63GB of VRAM on each of the eight A100 80 GB GPUs. The training, lasting three epochs, took just 20 minutes. The total cost for the VM was $8.88 per hour, resulting in $3, not including the time for experiments and bug fixes.

Conversations:

\-\-\-

<details>
    <summary>Friend 1 vs **Alexander Smirnov**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> hey) good**<br />
    **>>> you?**<br />
    \>\>\> good as well<br />
    \>\>\> what you were doing today?<br />
    **>>> played a board game**<br />
    **>>> I’ll go home now**<br />
    \>\>\> nice<br />
    \>\>\> what kind of game?<br />
    **>>> catan**<br />
    **>>> strategy**<br />
    **>>> very good**<br />
    \>\>\> who was there?<br />
    **>>> Max Yavich and Fedya**<br />
    \>\>\> who won?<br />
    **>>> Max**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> Прив) норм**<br />
    **>>> а у тебя?**<br />
    \>\>\> да тоже норм<br />
    \>\>\> чего делал сегодня?<br />
    **>>> играли в настолку**<br />
    **>>> ща поеду домой**<br />
    \>\>\> найс<br />
    \>\>\> что за настолка?<br />
    **>>> колонизаторы**<br />
    **>>> стратежка**<br />
    **>>> оч хорошая**<br />
    \>\>\> кто был?<br />
    **>>> Макс Явич и Федя**<br />
    \>\>\> кто выиграл?<br />
    **>>> Макс**

</details>

\-\-\-

<details>
    <summary>Friend 2 vs **Alexander Smirnov**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> hi, good**<br />
    **>>> let's meet in half an hour?**<br />
    \>\>\> yep<br />
    \>\>\> what did you want?<br />
    **>>> damn I haven’t finished the script for recalculating models yet**<br />
    **>>> and I need to finish it to send it to them**<br />
    **>>> this recalculation takes a lot of time, so I just want to turn around and start doing it and not waste time on preparation**<br />
    \>\>\> got it<br />
    \>\>\> what is the plan for today?<br />
    **>>> meet in half an hour to discuss what we are doing**<br />
    **>>> if decided, then I send an application to them and wait for a response**<br />
    **>>> if we haven’t decided, then we continue to work**<br />
    \>\>\> who do you mean by them?<br />
    **>>> investors**<br />
    **>>> https://www.ycombinator.com/howtoapply**<br />
    **>>> there are two tests)**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> прив, збс**<br />
    **>>> го кол через пол часа?**<br />
    \>\>\> да го<br />
    \>\>\> а чего ты хотел?<br />
    **>>> блять я еще не доделал скрипт по пересчету моделей**<br />
    **>>> и мне надо доделать чтобы отправить им**<br />
    **>>> вот этот пересчет занимает много времени поэтому я хочу просто уже развернуться и начать делать а не тратить время на подготовку**<br />
    \>\>\> понял<br />
    \>\>\> а какой вообще план на сегодня?<br />
    **>>> встречаемся через пол часа, обсуждаем что делаем**<br />
    **>>> если решили то отправляю заявку в им и жду ответа**<br />
    **>>> если не решили то продолжаем работать**<br />
    \>\>\> им это кому?<br />
    **>>> инвесторы**<br />
    **>>> https://www.ycombinator.com/howtoapply**<br />
    **>>> там два теста)**

</details>

\-\-\-

<details>
    <summary>Friend 3 vs **Alexander Smirnov**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> hey we’re sitting and solving problems**<br />
    \>\>\> what kind of problems?<br />
    **>>> data analysis +-**<br />
    \>\>\> and for what?<br />
    **>>> https://yandex.ru/cup/profile/**<br />
    **>>> it seems it just became more interesting**<br />
    \>\>\> cool<br />
    \>\>\> what are you planning this evening?<br />
    **>>> idk yet**<br />
    \>\>\> and on the weekend?<br />
    **>>> apparently I’ll also finish solving problems and get some work done**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> здарова нормуль сидим решаем задачки**<br />
    \>\>\> чего за задачки?<br />
    **>>> анализ данных +-**<br />
    \>\>\> а для чего?<br />
    **>>> https://yandex.ru/cup/profile/**<br />
    **>>> вроде просто поинтересней стало**<br />
    \>\>\> прикольно<br />
    \>\>\> что вечером планируешь?<br />
    **>>> хз пока**<br />
    \>\>\> а на выхах?<br />
    **>>> видимо тоже буду дорешивать задачи и с работой позаниматься**

</details>

\-\-\-

<details>
    <summary>Alexander Smirnov vs **Friend 1**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> hey)**<br />
    **>>> good**<br />
    **>>> you?**<br />
    \>\>\> that’s okay too<br />
    \>\>\> what did you do today?<br />
    **>>> well, I worked, of course**<br />
    **>>> and also**<br />
    **>>> met with Alena**<br />
    **>>> ate at the ramen shop with everyone**<br />
    **>>> and went home**<br />
    **>>> by the way, we booked a place for 14 people**<br />
    **>>> for the evening))**<br />
    \>\>\> cool<br />
    \>\>\> and what’s about university?<br />
    **>>> yeah**<br />
    **>>> studied a lot**<br />
    **>>> in general, every day I want to study more**<br />
    \>\>\> what is the hardest thing now?<br />
    **>>> well I don’t know**<br />
    **>>> it just takes a very long time**<br />
    **>>> there are some optimization methods that need to be rewritten**<br />
    **>>> so I think maybe it's not worth optimizing**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> прив)**<br />
    **>>> норм**<br />
    **>>> а у тебя?**<br />
    \>\>\> да тоже норм<br />
    \>\>\> чего делала сегодня?<br />
    **>>> ну я работала, конечно**<br />
    **>>> а еще**<br />
    **>>> с Аленой встретилась**<br />
    **>>> поели в раменной со всеми**<br />
    **>>> и домой**<br />
    **>>> кстати, мы забронировали рест на 14 человек**<br />
    **>>> для вечера))**<br />
    \>\>\> прикольно<br />
    \>\>\> а по унику чего?<br />
    **>>> ага**<br />
    **>>> заботала очень много**<br />
    **>>> вообще, каждый день хочу больше ботать**<br />
    \>\>\> а что сейчас самое тяжелое?<br />
    **>>> ну не знаю**<br />
    **>>> просто очень долго получается**<br />
    **>>> там некоторые методы оптимизации надо переписывать**<br />
    **>>> так что я думаю, может, это не стоит оптимизировать**

</details>

\-\-\-

<details>
    <summary>Alexander Smirnov vs **Friend 2**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> Hey, good, what about you?**<br />
    **>>> Are you already in Bangkok?**<br />
    \>\>\> yeah, already here<br />
    \>\>\> what are your plans for today?<br />
    **>>> Well, I would like to work on these pioneer tasks, if you don’t mind, we can do it together**<br />
    **>>> Or you can skip, I’ll finish the livechat tomorrow**<br />
    \>\>\> and what about live chat?<br />
    **>>> Damn right now I launched the front on the prod without this shit that generates this thing with a logo, and it swears, says to connect js from google analytics**<br />
    **>>> I understand that this is a fucking cringe, but I still tried to remember where to get it**<br />
    \>\>\> yeah got it<br />
    \>\>\> what will you do on weekends?<br />
    **>>> We are meeting with friends here before leaving, tomorrow we need to go to the hotel by 6 am to spend the day in the best traditions**<br />
    **>>> There's another party in the evening**<br />
    **>>> Actually, let’s have a call, I’ll tell you**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> Прив, норм, а у тебя?**<br />
    **>>> А ты в Бангкоке уже?**<br />
    \>\>\> ага, уже тут<br />
    \>\>\> какие планы на сегодня?<br />
    **>>> Ну я хотел бы поработать над этими пионерскими заданиями, если ты не против, то можно вместе поделать**<br />
    **>>> Или можешь пока сольёшься, я завтра буду допиливать лайвчат**<br />
    \>\>\> а чего там по лайвчату?<br />
    **>>> Да бля щас запустил на проде фронт без этого говна, которое генерирует эту штуку с лого, и она ругается, говорит, чтобы подключить js от google analytics**<br />
    **>>> Я понимаю, что это пиздец кринж, но я пошел все равно вспоминать, где его достать**<br />
    \>\>\> ага понял<br />
    \>\>\> что на выхах будешь делать?<br />
    **>>> Встречаемся с друзьями тут перед отъездом, завтра надо в отель к 6 утра поехать чтобы день провести в лучших традициях**<br />
    **>>> Там еще одна тусовка вечером**<br />
    **>>> На самом деле давай колл, расскажу**

</details>

\-\-\-

<details>
    <summary>Alexander Smirnov vs **Friend 3**</summary>

    \>\>\> hey<br />
    \>\>\> what's up?<br />
    **>>> Hi, haven’t you called yet?)**<br />
    **>>> Hey**<br />
    **>>> ok)**<br />
    **>>> I'm going to play Dota now**<br />
    **>>> Join if you want to)**<br />
    \>\>\> mb a little later)<br />
    \>\>\> what are your plans for weekends?<br />
    **>>> Lot of gyms/flexes/parks**<br />
    **>>> + maybe come to your place**<br />
    \>\>\> hmm well mb mb)<br />
    \>\>\> what's with your job btw?<br />
    **>>> Well, I'm waiting for the info**<br />
    \>\>\> did they say what deadlines are?<br />
    **>>> He said that there will be a call next week to discuss it**<br />
    \>\>\> remind me what this position is<br />
    **>>> Data Scientist**<br />
    **>>> The team is engaged in recommending products and other shit**<br />
    **>>> Creating model**<br />
    **>>> As part of this position, you will have to develop skills in machine learning, statistical data analysis, programming and much more**<br />
    **>>> It is how I understood it**

</details>

<details>
    <summary>original</summary>

    \>\>\> прив<br />
    \>\>\> как дела?<br />
    **>>> Прив, звонил еще нет?)**<br />
    **>>> Даров**<br />
    **>>> Нормально)**<br />
    **>>> Сча в доту иду**<br />
    **>>> Если хош присоединяйся)**<br />
    \>\>\> мб чуть позже)<br />
    \>\>\> какие планы на выхи?<br />
    **>>> Дохуя залов/флексов/парков**<br />
    **>>> + мона залипнуть к тебе**<br />
    \>\>\> хм ну мб мб)<br />
    \>\>\> а чего у тебя с работой в итоге?<br />
    **>>> НУ я жду инфу**<br />
    \>\>\> а какие сроки не сказали?<br />
    **>>> Сказал что на следующей неделе созвон где обсуждение будет**<br />
    \>\>\> а напомни что за позиция<br />
    **>>> Data Scientist**<br />
    **>>> Команда занимается рекомендацией товаров и прочей хуеты**<br />
    **>>> Создания моделькеи**<br />
    **>>> В рамках этой позиции ты должен будет развивать навыки машинного обучения, статистического анализа данных, программирования и многое другое**<br />
    **>>> Ну я так понял**

</details>

\-\-\-

Conversations have become more interesting and engaging, although there's still a risk of losing context. Russian language performance has improved, but errors still occur. I believe that before fine-tuning for a specific task with limited data, like mine, it would be beneficial to first fine-tune the model unsupervised on a large corpus of Russian texts. Additionally, incorporating common conversation partners' names as separate tokens might enhance the quality.

I wouldn't say it has turned out to be significantly better than LoRA. It might be more effective to focus solely on a single person and calculate the loss based only on my responses (or someone else's), instead of trying to learn about each and every conversational partner.

## Closing thoughts

Certainly, I had to cherry-pick the results, not because most of the model's replies were inadequate, but because many were simple responses like "I'll call you later," "busy," and "ok," which are naturally frequent in conversations. Despite this, it's clear that the model excels in mimicking the style of the person it's impersonating. It also captures the commonly discussed topics between two people. However, it significantly lacks context in conversations. Responding to queries like "yo, so?" or "what are your plans for the weekend" is challenging without having full context. Perhaps utilizing a system like [Rewind](https://www.rewind.ai/){target="\_blank"}, which captures everything the user does across the computer, could be beneficial.

## Code

You can find code for this project as well as instructions on how to replicate it yourself on your own Telegram dump in [my github repo](https://github.com/furiousteabag/doppelganger){target="\_blank"}. Training logs may be accessed on [WandB](https://wandb.ai/furiousteabag/doppelganger){target="\_blank"}.
