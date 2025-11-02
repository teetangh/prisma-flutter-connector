import { PrismaClient } from '@prisma/client';

const prisma = new PrismaClient();

async function main() {
  console.log('🌱 Seeding database...');

  // Create users
  const user1 = await prisma.user.upsert({
    where: { email: 'alice@example.com' },
    update: {},
    create: {
      email: 'alice@example.com',
      name: 'Alice Johnson',
    },
  });

  const user2 = await prisma.user.upsert({
    where: { email: 'bob@example.com' },
    update: {},
    create: {
      email: 'bob@example.com',
      name: 'Bob Smith',
    },
  });

  console.log('✅ Created users:', { user1: user1.name, user2: user2.name });

  // Create products
  const products = await Promise.all([
    prisma.product.upsert({
      where: { id: 'prod-laptop' },
      update: {},
      create: {
        id: 'prod-laptop',
        name: 'Gaming Laptop',
        description: 'High-performance gaming laptop with RTX 4080',
        price: 1999.99,
        stock: 15,
      },
    }),
    prisma.product.upsert({
      where: { id: 'prod-mouse' },
      update: {},
      create: {
        id: 'prod-mouse',
        name: 'Wireless Mouse',
        description: 'Ergonomic wireless mouse with 6 buttons',
        price: 49.99,
        stock: 50,
      },
    }),
    prisma.product.upsert({
      where: { id: 'prod-keyboard' },
      update: {},
      create: {
        id: 'prod-keyboard',
        name: 'Mechanical Keyboard',
        description: 'RGB mechanical keyboard with Cherry MX switches',
        price: 129.99,
        stock: 30,
      },
    }),
    prisma.product.upsert({
      where: { id: 'prod-monitor' },
      update: {},
      create: {
        id: 'prod-monitor',
        name: '4K Monitor',
        description: '32-inch 4K UHD monitor with HDR',
        price: 599.99,
        stock: 20,
      },
    }),
    prisma.product.upsert({
      where: { id: 'prod-headset' },
      update: {},
      create: {
        id: 'prod-headset',
        name: 'Gaming Headset',
        description: '7.1 surround sound gaming headset',
        price: 89.99,
        stock: 40,
      },
    }),
  ]);

  console.log('✅ Created products:', products.map((p) => p.name).join(', '));

  // Create sample orders
  const order1 = await prisma.order.create({
    data: {
      userId: user1.id,
      status: 'DELIVERED',
      total: 1999.99 + 49.99,
      items: {
        create: [
          {
            productId: 'prod-laptop',
            quantity: 1,
            price: 1999.99,
          },
          {
            productId: 'prod-mouse',
            quantity: 1,
            price: 49.99,
          },
        ],
      },
    },
  });

  const order2 = await prisma.order.create({
    data: {
      userId: user2.id,
      status: 'PROCESSING',
      total: 129.99 + 89.99,
      items: {
        create: [
          {
            productId: 'prod-keyboard',
            quantity: 1,
            price: 129.99,
          },
          {
            productId: 'prod-headset',
            quantity: 1,
            price: 89.99,
          },
        ],
      },
    },
  });

  console.log('✅ Created orders:', { order1: order1.id, order2: order2.id });

  console.log('🎉 Seeding completed successfully!');
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e);
    process.exit(1);
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
