---
title: none
date: none
---

## Converging to the idea

Applying tools like ChatGPT to customer support was a pretty obvious idea. It promised to benefit both customers using self-service FAQs and agents by speeding up responses and reducing the need for first-line support. So, we started digging in.

We developed a prototype and reached out to industry experts for feedback. This eventually led us to [LiveChat incubator](https://incubator.text.com/){target="\_blank"} where LiveChat agents tested our agent assistant tool (this tool later became an [app on the LiveChat marketplace](https://www.livechat.com/marketplace/apps/askguru/){target="\_blank"}). From these tests it became clear that leveraging internal documents and previous chats improves the chatbot's ability to respond accurately without involving an agent. It worked great for answering straightforward questions like "What's the maximum file size for upload?" but at the same time it struggled with action-oriented queries such as "I want to cancel my subscription.". Overall, we looked at this experiment as a positive sign and started thinking about our unique edge.

Looking at AI customer support competitors like [Yuma](https://yuma.ai/){target="\_blank"}, [OpenSight](https://www.ycombinator.com/companies/opensight){target="\_blank"}, [Parabolic](https://www.growparabolic.com/){target="\_blank"}, we noticed that everyone was targeting end clients — teams responsible for customer support, individual merchants, or outsourcing companies. Howewer, we felt that this approach have a downside: most clients were already using customer support software like Zendesk, Intercom, and a long tail of smaller ones which meanth we should create numerous integrations similar to our LiveChat collaboration. But large software providers would inevitably introduce native AI features, which would always outperform non-native marketplace apps. Indeed, we saw signs that LiveChat was developing its own AI solutions ^[[LiveChat existing and upcoming AI features (livechat.com)](https://www.livechat.com/features/ai/){target="\_blank"}], making us realize that our marketplace app might eventually become redundant over time.

This realization led us to a hypothesis that was driving the development of AskGuru for these months: **SMBs in the Customer support and Knowledge Management software development fields, who have the resources but lack the engineering capacity, would prefer to buy ready-to-use AI tools rather than develop them in-house**. We believed it was crucial for these smaller CS/KMS providers to integrate ChatGPT-powered features immediately for automatic Q&A, dialogue summarization, semantic retrieval, and more. This urgency comes from observing major players like Intercom, Zendesk, and Zoho rapidly incorporating AI into their offerings ^[[Revolutionizing CS/CX: Market overview (askguru.ai/blog)](https://www.askguru.ai/blog/revolutionizing-cs-cx-a-deep-dive-into-the-ai-capabilities-of-leading-cs-cx-software-providers){target="\_blank"}], with smaller companies likely to follow suit.

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