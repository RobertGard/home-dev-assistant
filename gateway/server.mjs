import Fastify from 'fastify'
import { z } from 'zod'
import { createOpencodeClient } from '@opencode-ai/sdk'

const fastify = Fastify({
  logger: true,
  requestTimeout: Number(process.env.REQUEST_TIMEOUT_MS || 1800000),
  keepAliveTimeout: Number(process.env.KEEP_ALIVE_TIMEOUT_MS || 1800000),
  connectionTimeout: Number(process.env.REQUEST_TIMEOUT_MS || 1800000),
})

fastify.server.headersTimeout = Number(process.env.HEADERS_TIMEOUT_MS || 1805000)

const authHeader =
  'Basic ' +
  Buffer.from(`opencode:${process.env.OPENCODE_PASSWORD}`, 'utf8').toString('base64')

const client = createOpencodeClient({
  baseUrl: process.env.OPENCODE_BASE_URL || 'http://127.0.0.1:4096',
  fetch: async (url, init = {}) =>
    fetch(url, {
      ...init,
      headers: {
        ...(init.headers || {}),
        Authorization: authHeader,
      },
    }),
})

const Input = z.object({
  sessionId: z.string().optional(),
  title: z.string().optional(),
  agent: z.string().default(process.env.DEFAULT_AGENT || 'build'),
  prompt: z.string(),
  context: z.array(z.string()).default([]),
  model: z
    .object({
      providerID: z.string(),
      modelID: z.string(),
    })
    .optional(),
})

const OutputSchema = {
  type: 'object',
  properties: {
    status: { type: 'string', enum: ['ok', 'needs_input', 'retry', 'error'] },
    summary: { type: 'string' },
    artifacts: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          kind: { type: 'string' },
          path: { type: 'string' },
          description: { type: 'string' },
        },
        required: ['kind', 'path', 'description'],
      },
    },
    tests: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          name: { type: 'string' },
          status: { type: 'string', enum: ['passed', 'failed', 'skipped'] },
          details: { type: 'string' },
        },
        required: ['name', 'status', 'details'],
      },
    },
    next_step: { type: 'string' },
    commands_run: {
      type: 'array',
      items: { type: 'string' },
    },
    machine: {
      type: 'object',
      properties: {
        repo_dirty: { type: 'boolean' },
        branch: { type: 'string' },
        commit: { type: 'string' },
      },
      required: ['repo_dirty', 'branch', 'commit'],
    },
  },
  required: ['status', 'summary'],
}

fastify.post('/run', async (request, reply) => {
  const input = Input.parse(request.body)

  let sessionId = input.sessionId
  if (!sessionId) {
    const created = await client.session.create({
      body: { title: input.title || 'queued-task' },
    })
    sessionId = created.data.id
  }

  for (const extra of input.context) {
    await client.session.prompt({
      path: { id: sessionId },
      body: {
        noReply: true,
        parts: [{ type: 'text', text: extra }],
      },
    })
  }

  const result = await client.session.prompt({
    path: { id: sessionId },
    body: {
      agent: input.agent,
      model: input.model,
      parts: [{ type: 'text', text: input.prompt }],
      format: {
        type: 'json_schema',
        retryCount: 2,
        schema: OutputSchema,
      },
    },
  })

  const data = result.data.info.structured_output
  if (!data) {
    return reply.code(500).send({
      sessionId,
      status: 'error',
      summary: 'Structured output missing',
    })
  }

  return {
    sessionId,
    ...data,
  }
})

await fastify.listen({
  host: '0.0.0.0',
  port: Number(process.env.PORT || 9080),
})
