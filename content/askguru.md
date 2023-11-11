---
title: none
date: none
---

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
