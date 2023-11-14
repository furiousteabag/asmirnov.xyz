---
title: none
date: none
---

Almost a year ago, a month after ChatGPT was released, me and my friend began working on [AskGuru](https://askguru.ai/){target="\_blank"}: an AI toolkit designed for customer support software providers. Essentially, it's a collection of easy-to-integrate tools that enable these providers to incorporate AI features such as Q&A over documents and chats, summarization, and semantic search into various aspects of their product, whether it's a customer-facing chatbot or a copilot tool for agents.

Recently, my co-founder left to join another company, so I thought it would be a great time to look back and reflect on what we did and what we learned building [AI startup in 2023](./images/askguru-ai-startup.png){target="\_blank"}.

## Converging to the idea

Applying ChatGPT to customer support was a pretty obvious idea. It promised to benefit both customers using self-service FAQs and agents by speeding up responses and reducing the need for first-line support. So, we started digging in.

We developed a prototype and reached out to industry experts for feedback. This eventually led us to [LiveChat incubator](https://incubator.text.com/){target="\_blank"} where LiveChat agents tested our agent assistant tool (this tool later became an [app on the LiveChat marketplace](https://www.livechat.com/marketplace/apps/askguru/){target="\_blank"}). From these tests it became clear that leveraging internal documents and previous chats improves the chatbot's ability to respond accurately without involving an agent. It worked great for answering straightforward questions like "What's the maximum file size for upload?" but at the same time it struggled with action-oriented queries such as "I want to cancel my subscription.". Overall, we looked at this experiment as a positive sign and started thinking about our unique edge.

Looking at AI customer support competitors like [Yuma](https://yuma.ai/){target="\_blank"}, [OpenSight](https://www.ycombinator.com/companies/opensight){target="\_blank"}, [Parabolic](https://www.growparabolic.com/){target="\_blank"}, we noticed that everyone was targeting end clients — teams responsible for customer support, individual merchants, or outsourcing companies. Howewer, we felt that this approach have a downside: most clients were already using customer support software like Zendesk, Intercom, and a long tail of smaller ones which meanth we should create numerous integrations similar to our LiveChat collaboration. But large software providers would inevitably introduce native AI features, which would always outperform non-native marketplace apps. Indeed, we saw signs that LiveChat was developing its own AI solutions ^[[LiveChat existing and upcoming AI features (livechat.com)](https://www.livechat.com/features/ai/){target="\_blank"}], making us realize that our marketplace app might eventually become redundant over time.

This realization led us to a hypothesis that was driving the development of AskGuru for these months: **SMBs in the Customer support and Knowledge Management software development fields, who have the resources but lack the engineering capacity, would prefer to buy ready-to-use AI tools rather than develop them in-house**. We believed it was crucial for these smaller CS/KMS providers to integrate ChatGPT-powered features immediately for automatic Q&A, dialogue summarization, semantic retrieval, and more. This urgency comes from observing major players like Intercom, Zendesk, and Zoho rapidly incorporating AI into their offerings ^[[Revolutionizing CS/CX: Market overview (askguru.ai/blog)](https://www.askguru.ai/blog/revolutionizing-cs-cx-a-deep-dive-into-the-ai-capabilities-of-leading-cs-cx-software-providers){target="\_blank"}], with smaller companies likely to follow suit.


## Building in the AI space

Situation when the product is not gaining much traction is not unique in any sense. It's often a good time to pause, reflect on learnings, and maybe pivot. But here's the thing: I'm not keen on continuing to develop a product where OpenAI API lies as the core.

Half a year ago I was convinced that building additional features around powerful foundation AI model is a viable strategy. Howewer, OpenAI's recent updates ^[[New models and developer products announced at DevDay (openai.com/blog)](https://openai.com/blog/new-models-and-developer-products-announced-at-devday){target="\_blank"}] ^[[Introducing GPTs (openai.com/blog)](https://openai.com/blog/introducing-gpts){target="\_blank"}] including the [Assistants API](https://platform.openai.com/docs/assistants/overview){target="\_blank"} with [RAG](https://platform.openai.com/docs/assistants/tools/knowledge-retrieval){target="\_blank"}, [history thread management](https://platform.openai.com/docs/assistants/how-it-works/managing-threads-and-messages){target="\_blank"} and [code interpreter](https://platform.openai.com/docs/assistants/tools/code-interpreter){target="\_blank"} show that they're aiming to be more than just a provider of foundation models. They're willing to be an all-in-one AI development platform. This shift makes it risky to have their API as the backbone of a product, because there's always the chance OpenAI might add features which makes my product obsolete.

A common strategy for creating a unique selling point is collecting client data to fine-tune custom models, creating a so-called "data flywheel". For me it is hard to agree with that because no company wants their data used as training material for a model that'll eventually serve their competitors. This means that I will end up fine-tuning models for each client with their data, which isn't scalable and involves a lot of manual work. That means that everything I need is a single Q&A RAG model, finetuned to utilize context and follow specific output format. Such model could be finetuned on a synthetic datasets from GPT4 outputs without a need of a flywheels.

An even bigger question is whether local models are necessary at all when OpenAI's models are so efficient. In our interviews, we've often heard companies express concerns about using OpenAI's API, fearing it might compromise their clients' data. These companies generally fall into three categories:

1. Those who simply don't need or want AI.

2. Those who don't trust OpenAI API but trust established providers like [Azure OpenAI Service](https://azure.microsoft.com/en-in/products/ai-services/openai-service){target="\_blank"}.

3. Companies in sectors like banking, insurance, or consulting. Many haven't moved to cloud computing and rely on their own data centers. For them, the return on investment for AI features like Q&A and summarization isn't clear, given the need for significant CPU, RAM, or GPU resources.

Given that, I don't think any local models are needed in a customer support space.

Generally, AI has become too commoditized to be the central feature of a product. It's now just another tool, like a database or cloud service. It is especially sad for me as a Machine Learning engineer!

## Rant about chatbots

It could be worth continue trying to find unique edge and developing a product that stands out from those quickly built on the OpenAI stack. However, I realized that I don't have a strong passion for customer support as a whole. In my entire life, I've never had a case where a bot actually solved my problem. Either I managed to find the information or take the action myself (like changing a delivery address), or my request was so specific that it wasn't covered by scripts or documentation and needed a real person's help.

While working on AskGuru, I've come to believe that the existence of chatbots for information and actions is more about poor UX/UI and the absence of a solid search engine like [Algolia](https://www.algolia.com/){target="\_blank"}. The real value in a chat popup, in my view, is the live agent. They can do things and access info not readily available to users, like escalating technical bugs or handling complaints and disputes.


## Tech details

The main value proposition of AskGuru is Q&A over PDFs, crawled websites, markdown, and plain text files. We've enhanced this with several features:

- Canned replies: When a user's question closely matches a predefined query, we automatically provide the set answer
- Security groups: This ensures that users within a single workspace only see results from documents they're authorized to access
- Automatic translation of responses to match the query language
- Voice input

AskGuru is primarily designed for use via a web API. This allows our clients to natively integrate our features into their products, such as a Knowledge Base provider improving their search results with our answers. Additionally, we made a chat popup for embedding a chat-over-docs widget on websites and a [Livechat marketplace app](https://www.livechat.com/marketplace/apps/askguru/){target="\_blank"} to assist agents in preparing responses.

The stack we have:

- Python FastAPI backend with Uvicorn & Gunicorn, and Pytest for testing
- An ML FastAPI microservice, essentially a wrapper for the OpenAI API
- A React, TypeScript, and Vite-powered chat popup
- MongoDB for data storage and Milvus for handling embeddings
- Tools like Mongo Express and Attu for managing databases above
- Redash for log analysis from MongoDB
- Nginx as a reverse proxy for backend services and to serve front-end builds

These components interact as shown here:

![](./images/askguru-components.svg)

We self-host everything on standard VMs across AWS, Vultr, and GCP, using docker-compose. We don't use services like Managed Databases or Cloud Run offered by cloud providers because it makes us feel bounded to specific provider. It paid off when our GCP credits ^[[Google for Startups (cloud.google.com/startup)](https://cloud.google.com/startup){target="\_blank"}] ran out and we were able to move everything to AWS withing an hour, thanks to the credits we had from [NVIDIA Inception program](https://www.nvidia.com/startups/){target="\_blank"}). While self-hosting raises questions about database backups and microservice scalability, our relatively low request volume (averaging 100/day) has meant these are not immediate concerns.

### Flow of handling user request

The central feature of AskGuru is the GET /answer endpoint, which provides responses to user inquiries based on certain parameters. The flowchart below illustrates the process of handling these requests:

![](./images/askguru-answer-flow.svg)

### Vector databases

We used Milvus for storing vector embeddings. We enjoyed working with their Python SDK and exploring their docs. Once we encountered an issue where Milvus consuming excessive CPU while idle ^[[[Bug]: High CPU usage on idle (github.com/milvus-io/milvus/issues/)](https://github.com/milvus-io/milvus/issues/24812){target="\_blank"}] but the Milvus team responded swiftly and efficiently, helping me resolve the issue ASAP. Other challenges, such as eventual consistency and switching message brokers, were resolved by reviewing the docs and config files.

Despite my positive experience with Milvus, I'm inclined not to use any vector database for my next project. The sole feature I require from a vector database is indexing for quick retrieval, and I don't see the need to manage an entire separate database just for this one functionality. Instead, I'm considering some extensions to existing, established databases like those available for PostgreSQL ^[[pgvector: Open-source vector similarity search for Postgres (github.com/pgvector)](https://github.com/pgvector/pgvector){target="\_blank"}] ^[[Lantern: open-source PostgreSQL database extension to store vector data, generate embeddings, and handle vector search operations (github.com/lanterndata)](https://github.com/lanterndata/lantern){target="\_blank"}].

From my perspective, the vector databases field currently seems more focused on marketing tactics (like which database OpenAI uses in their sample notebooks ^[[Fine-Tuning for Retrieval Augmented Generation (RAG) with Qdrant (cookbook.openai.com)](https://cookbook.openai.com/examples/fine-tuned_qa/ft_retrieval_augmented_generation_qdrant){target="\_blank"}]), connectors to outer world (such as SDKs ^[[Qdrant vs Pinecone (qdrant.tech/documentation)](https://qdrant.tech/documentation/overview/qdrant-alternatives/#supported-technologies){target="\_blank"}]), and tutorials for a quick start, rather than an actual competition of quality and speed. Given the additional overhead of integrating a new database for just a single vector indexing feature, and considering the presence of traditional databases like PostgreSQL, which I plan to use anyway, the value proposition just isn't there for me.
