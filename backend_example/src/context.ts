import { PrismaClient } from '@prisma/client';
import { PubSub } from 'graphql-subscriptions';

// Singleton Prisma Client instance
const prisma = new PrismaClient({
  log: process.env.NODE_ENV === 'development' ? ['query', 'error', 'warn'] : ['error'],
});

// PubSub for subscriptions
export const pubsub = new PubSub();

export interface Context {
  prisma: PrismaClient;
  pubsub: PubSub;
}

export function createContext(): Context {
  return {
    prisma,
    pubsub,
  };
}

// Graceful shutdown
process.on('SIGINT', async () => {
  await prisma.$disconnect();
  process.exit(0);
});

process.on('SIGTERM', async () => {
  await prisma.$disconnect();
  process.exit(0);
});
