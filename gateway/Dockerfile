FROM node:22-bookworm-slim

WORKDIR /app

COPY package.json ./
RUN npm install

COPY server.mjs ./

EXPOSE 9080

CMD ["npm", "run", "start"]
