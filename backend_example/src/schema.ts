import SchemaBuilder from '@pothos/core';
import PrismaPlugin from '@pothos/plugin-prisma';
import type PrismaTypes from '@pothos/plugin-prisma/generated';
import { PrismaClient, OrderStatus } from '@prisma/client';
import { Context, pubsub } from './context';
import { DateTimeResolver } from 'graphql-scalars';

const builder = new SchemaBuilder<{
  PrismaTypes: PrismaTypes;
  Context: Context;
  Scalars: {
    DateTime: {
      Input: Date;
      Output: Date;
    };
  };
}>({
  plugins: [PrismaPlugin],
  prisma: {
    client: (ctx) => ctx.prisma,
  },
});

// Add DateTime scalar
builder.addScalarType('DateTime', DateTimeResolver, {});

// Enums
builder.enumType(OrderStatus, {
  name: 'OrderStatus',
});

// Object Types
builder.prismaObject('User', {
  fields: (t) => ({
    id: t.exposeID('id'),
    email: t.exposeString('email'),
    name: t.exposeString('name'),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    updatedAt: t.expose('updatedAt', { type: 'DateTime' }),
    orders: t.relation('orders'),
  }),
});

builder.prismaObject('Product', {
  fields: (t) => ({
    id: t.exposeID('id'),
    name: t.exposeString('name'),
    description: t.exposeString('description'),
    price: t.exposeFloat('price'),
    stock: t.exposeInt('stock'),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    updatedAt: t.expose('updatedAt', { type: 'DateTime' }),
  }),
});

builder.prismaObject('Order', {
  fields: (t) => ({
    id: t.exposeID('id'),
    userId: t.exposeString('userId'),
    status: t.expose('status', { type: OrderStatus }),
    total: t.exposeFloat('total'),
    createdAt: t.expose('createdAt', { type: 'DateTime' }),
    updatedAt: t.expose('updatedAt', { type: 'DateTime' }),
    user: t.relation('user'),
    items: t.relation('items'),
  }),
});

builder.prismaObject('OrderItem', {
  fields: (t) => ({
    id: t.exposeID('id'),
    orderId: t.exposeString('orderId'),
    productId: t.exposeString('productId'),
    quantity: t.exposeInt('quantity'),
    price: t.exposeFloat('price'),
    product: t.relation('product'),
  }),
});

// Input Types
const CreateUserInput = builder.inputType('CreateUserInput', {
  fields: (t) => ({
    email: t.string({ required: true }),
    name: t.string({ required: true }),
  }),
});

const UpdateUserInput = builder.inputType('UpdateUserInput', {
  fields: (t) => ({
    email: t.string(),
    name: t.string(),
  }),
});

const CreateProductInput = builder.inputType('CreateProductInput', {
  fields: (t) => ({
    name: t.string({ required: true }),
    description: t.string({ required: true }),
    price: t.float({ required: true }),
    stock: t.int({ required: false }),
  }),
});

const UpdateProductInput = builder.inputType('UpdateProductInput', {
  fields: (t) => ({
    name: t.string(),
    description: t.string(),
    price: t.float(),
    stock: t.int(),
  }),
});

const OrderItemInput = builder.inputType('OrderItemInput', {
  fields: (t) => ({
    productId: t.string({ required: true }),
    quantity: t.int({ required: true }),
  }),
});

const CreateOrderInput = builder.inputType('CreateOrderInput', {
  fields: (t) => ({
    userId: t.string({ required: true }),
    items: t.field({ type: [OrderItemInput], required: true }),
    status: t.field({ type: OrderStatus, required: false }),
  }),
});

const UpdateOrderInput = builder.inputType('UpdateOrderInput', {
  fields: (t) => ({
    status: t.field({ type: OrderStatus }),
  }),
});

// Queries
builder.queryType({
  fields: (t) => ({
    // Users
    user: t.prismaField({
      type: 'User',
      nullable: true,
      args: {
        id: t.arg.string({ required: true }),
      },
      resolve: (query, _parent, args, ctx) =>
        ctx.prisma.user.findUnique({
          ...query,
          where: { id: args.id },
        }),
    }),
    users: t.prismaField({
      type: ['User'],
      args: {
        emailContains: t.arg.string(),
        nameContains: t.arg.string(),
      },
      resolve: (query, _parent, args, ctx) =>
        ctx.prisma.user.findMany({
          ...query,
          where: {
            email: args.emailContains ? { contains: args.emailContains } : undefined,
            name: args.nameContains ? { contains: args.nameContains } : undefined,
          },
        }),
    }),

    // Products
    product: t.prismaField({
      type: 'Product',
      nullable: true,
      args: {
        id: t.arg.string({ required: true }),
      },
      resolve: (query, _parent, args, ctx) =>
        ctx.prisma.product.findUnique({
          ...query,
          where: { id: args.id },
        }),
    }),
    products: t.prismaField({
      type: ['Product'],
      args: {
        nameContains: t.arg.string(),
        priceUnder: t.arg.float(),
        priceOver: t.arg.float(),
        inStock: t.arg.boolean(),
      },
      resolve: (query, _parent, args, ctx) =>
        ctx.prisma.product.findMany({
          ...query,
          where: {
            name: args.nameContains ? { contains: args.nameContains } : undefined,
            price: {
              ...(args.priceUnder ? { lte: args.priceUnder } : {}),
              ...(args.priceOver ? { gte: args.priceOver } : {}),
            },
            stock: args.inStock ? { gt: 0 } : undefined,
          },
        }),
    }),

    // Orders
    order: t.prismaField({
      type: 'Order',
      nullable: true,
      args: {
        id: t.arg.string({ required: true }),
      },
      resolve: (query, _parent, args, ctx) =>
        ctx.prisma.order.findUnique({
          ...query,
          where: { id: args.id },
        }),
    }),
    orders: t.prismaField({
      type: ['Order'],
      args: {
        userId: t.arg.string(),
        status: t.arg({ type: OrderStatus }),
      },
      resolve: (query, _parent, args, ctx) =>
        ctx.prisma.order.findMany({
          ...query,
          where: {
            userId: args.userId,
            status: args.status ?? undefined,
          },
          orderBy: { createdAt: 'desc' },
        }),
    }),
  }),
});

// Mutations
builder.mutationType({
  fields: (t) => ({
    // User mutations
    createUser: t.prismaField({
      type: 'User',
      args: {
        input: t.arg({ type: CreateUserInput, required: true }),
      },
      resolve: async (query, _parent, args, ctx) =>
        ctx.prisma.user.create({
          ...query,
          data: args.input,
        }),
    }),
    updateUser: t.prismaField({
      type: 'User',
      args: {
        id: t.arg.string({ required: true }),
        input: t.arg({ type: UpdateUserInput, required: true }),
      },
      resolve: async (query, _parent, args, ctx) =>
        ctx.prisma.user.update({
          ...query,
          where: { id: args.id },
          data: args.input,
        }),
    }),
    deleteUser: t.boolean({
      args: {
        id: t.arg.string({ required: true }),
      },
      resolve: async (_parent, args, ctx) => {
        await ctx.prisma.user.delete({ where: { id: args.id } });
        return true;
      },
    }),

    // Product mutations
    createProduct: t.prismaField({
      type: 'Product',
      args: {
        input: t.arg({ type: CreateProductInput, required: true }),
      },
      resolve: async (query, _parent, args, ctx) =>
        ctx.prisma.product.create({
          ...query,
          data: {
            ...args.input,
            stock: args.input.stock ?? 0,
          },
        }),
    }),
    updateProduct: t.prismaField({
      type: 'Product',
      args: {
        id: t.arg.string({ required: true }),
        input: t.arg({ type: UpdateProductInput, required: true }),
      },
      resolve: async (query, _parent, args, ctx) =>
        ctx.prisma.product.update({
          ...query,
          where: { id: args.id },
          data: args.input,
        }),
    }),
    deleteProduct: t.boolean({
      args: {
        id: t.arg.string({ required: true }),
      },
      resolve: async (_parent, args, ctx) => {
        await ctx.prisma.product.delete({ where: { id: args.id } });
        return true;
      },
    }),

    // Order mutations
    createOrder: t.prismaField({
      type: 'Order',
      args: {
        input: t.arg({ type: CreateOrderInput, required: true }),
      },
      resolve: async (query, _parent, args, ctx) => {
        // Calculate total from products
        const productIds = args.input.items.map((item) => item.productId);
        const products = await ctx.prisma.product.findMany({
          where: { id: { in: productIds } },
        });

        const total = args.input.items.reduce((sum, item) => {
          const product = products.find((p) => p.id === item.productId);
          return sum + (product ? product.price * item.quantity : 0);
        }, 0);

        const order = await ctx.prisma.order.create({
          ...query,
          data: {
            userId: args.input.userId,
            status: args.input.status ?? 'PENDING',
            total,
            items: {
              create: args.input.items.map((item) => {
                const product = products.find((p) => p.id === item.productId);
                return {
                  productId: item.productId,
                  quantity: item.quantity,
                  price: product?.price ?? 0,
                };
              }),
            },
          },
        });

        // Publish subscription event
        pubsub.publish('ORDER_CREATED', { orderCreated: order });

        return order;
      },
    }),
    updateOrder: t.prismaField({
      type: 'Order',
      args: {
        id: t.arg.string({ required: true }),
        input: t.arg({ type: UpdateOrderInput, required: true }),
      },
      resolve: async (query, _parent, args, ctx) => {
        const order = await ctx.prisma.order.update({
          ...query,
          where: { id: args.id },
          data: args.input,
        });

        // Publish subscription event
        if (args.input.status) {
          pubsub.publish(`ORDER_STATUS_${args.id}`, { orderStatusChanged: order });
        }

        return order;
      },
    }),
  }),
});

// Subscriptions
builder.subscriptionType({
  fields: (t) => ({
    orderCreated: t.field({
      type: 'Order',
      args: {
        userId: t.arg.string(),
      },
      subscribe: (_parent, args) => {
        // Simple subscription - in production, filter by userId
        return pubsub.asyncIterator(['ORDER_CREATED']);
      },
      resolve: (payload: any) => payload.orderCreated,
    }),
    orderStatusChanged: t.field({
      type: 'Order',
      args: {
        orderId: t.arg.string({ required: true }),
      },
      subscribe: (_parent, args) =>
        pubsub.asyncIterator([`ORDER_STATUS_${args.orderId}`]),
      resolve: (payload: any) => payload.orderStatusChanged,
    }),
  }),
});

export const schema = builder.toSchema();
