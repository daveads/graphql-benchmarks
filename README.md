# GraphQL Benchmarks <!-- omit from toc -->

[![Open in GitHub Codespaces](https://github.com/codespaces/badge.svg)](https://codespaces.new/tailcallhq/graphql-benchmarks)

Explore and compare the performance of the fastest GraphQL frameworks through our comprehensive benchmarks.

- [Introduction](#introduction)
- [Quick Start](#quick-start)
- [Benchmark Results](#benchmark-results)
  - [Throughput (Higher is better)](#throughput-higher-is-better)
  - [Latency (Lower is better)](#latency-lower-is-better)
- [Architecture](#architecture)
  - [WRK](#wrk)
  - [GraphQL](#graphql)
  - [Nginx](#nginx)
  - [Jsonplaceholder](#jsonplaceholder)
- [GraphQL Schema](#graphql-schema)
- [Contribute](#contribute)

[Tailcall]: https://github.com/tailcallhq/tailcall
[Gqlgen]: https://github.com/99designs/gqlgen
[Apollo GraphQL]: https://github.com/apollographql/apollo-server
[Netflix DGS]: https://github.com/netflix/dgs-framework
[Caliban]: https://github.com/ghostdogpr/caliban
[async-graphql]: https://github.com/async-graphql/async-graphql
[Hasura]: https://github.com/hasura/graphql-engine
[GraphQL JIT]: https://github.com/zalando-incubator/graphql-jit

## Introduction

This document presents a comparative analysis of several renowned GraphQL frameworks. Dive deep into the performance metrics, and get insights into their throughput and latency.

> **NOTE:** This is a work in progress suite of benchmarks, and we would appreciate help from the community to add more frameworks or tune the existing ones for better performance.

## Quick Start

Get started with the benchmarks:

1. Click on this [link](https://codespaces.new/tailcallhq/graphql-benchmarks) to set up on GitHub Codespaces.
2. Once set up in Codespaces, initiate the benchmark tests:

```bash
./setup.sh
./run_benchmarks.sh
```

## Benchmark Results

<!-- PERFORMANCE_RESULTS_START -->

| Query | Server | Requests/sec | Latency (ms) | Relative |
|-------:|--------:|--------------:|--------------:|---------:|
| 1 | `{ posts { id userId title user { id name email }}}` |
|| [Tailcall] | `28,472.50` | `3.50` | `109.21x` |
|| [async-graphql] | `1,809.10` | `55.17` | `6.94x` |
|| [Caliban] | `1,524.36` | `65.30` | `5.85x` |
|| [Hasura] | `1,457.24` | `68.38` | `5.59x` |
|| [GraphQL JIT] | `1,234.66` | `80.63` | `4.74x` |
|| [Gqlgen] | `725.33` | `136.73` | `2.78x` |
|| [Netflix DGS] | `353.42` | `226.42` | `1.36x` |
|| [Apollo GraphQL] | `260.70` | `376.78` | `1.00x` |
| 2 | `{ posts { title }}` |
|| [Tailcall] | `60,583.90` | `1.64` | `47.18x` |
|| [async-graphql] | `9,225.90` | `11.00` | `7.18x` |
|| [Caliban] | `8,957.04` | `11.55` | `6.97x` |
|| [Hasura] | `2,411.88` | `41.46` | `1.88x` |
|| [Gqlgen] | `2,087.99` | `49.59` | `1.63x` |
|| [Apollo GraphQL] | `1,692.26` | `59.05` | `1.32x` |
|| [Netflix DGS] | `1,564.19` | `71.07` | `1.22x` |
|| [GraphQL JIT] | `1,284.21` | `77.76` | `1.00x` |
| 3 | `{ greet }` |
|| [Caliban] | `68,806.90` | `1.11` | `27.10x` |
|| [Tailcall] | `63,678.70` | `1.59` | `25.08x` |
|| [async-graphql] | `50,200.00` | `2.00` | `19.77x` |
|| [Gqlgen] | `45,929.00` | `5.19` | `18.09x` |
|| [Netflix DGS] | `8,017.01` | `15.05` | `3.16x` |
|| [Apollo GraphQL] | `7,858.71` | `13.03` | `3.10x` |
|| [GraphQL JIT] | `5,016.67` | `19.90` | `1.98x` |
|| [Hasura] | `2,538.60` | `39.47` | `1.00x` |

<!-- PERFORMANCE_RESULTS_END -->



### 1. `{posts {title body user {name}}}`
#### Throughput (Higher is better)

![Throughput Histogram](assets/req_sec_histogram1.png)

#### Latency (Lower is better)

![Latency Histogram](assets/latency_histogram1.png)

### 2. `{posts {title body}}`
#### Throughput (Higher is better)

![Throughput Histogram](assets/req_sec_histogram2.png)

#### Latency (Lower is better)

![Latency Histogram](assets/latency_histogram2.png)

### 3. `{greet}`
#### Throughput (Higher is better)

![Throughput Histogram](assets/req_sec_histogram3.png)

#### Latency (Lower is better)

![Latency Histogram](assets/latency_histogram3.png)

## Architecture

![Architecture Diagram](assets/architecture.png)

A client (`wrk`) sends requests to a GraphQL server to fetch post titles. The GraphQL server, in turn, retrieves data from an external source, `jsonplaceholder.typicode.com`, routed through the `nginx` reverse proxy.

### WRK

`wrk` serves as our test client, sending GraphQL requests at a high rate.

### GraphQL

Our tested GraphQL server. We evaluated various implementations, ensuring no caching on the GraphQL server side.

### Nginx

A reverse-proxy that caches every response, mitigating rate-limiting and reducing network uncertainties.

### Jsonplaceholder

The primary upstream service forming the base for our GraphQL API. We query its `/posts` API via the GraphQL server.

## GraphQL Schema

Inspect the generated GraphQL schema employed for the benchmarks:

```graphql
schema {
  query: Query
}

type Query {
  posts: [Post]
}

type Post {
  id: Int!
  userId: Int!
  title: String!
  body: String!
  user: User
}

type User {
  id: Int!
  name: String!
  username: String!
  email: String!
  phone: String
  website: String
}
```

## Contribute

Your insights are invaluable! Test these benchmarks, share feedback, or contribute by adding more GraphQL frameworks or refining existing ones. Open an issue or a pull request, and let's build a robust benchmarking resource together!
