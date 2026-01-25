FROM node:20-alpine

WORKDIR /app

COPY package*.json ./

RUN npm install --omit=dev

COPY . .

# Generate Prisma Client for the target environment
RUN npx prisma generate

RUN mkdir -p uploads

EXPOSE 5000

CMD ["node", "server.js"]

