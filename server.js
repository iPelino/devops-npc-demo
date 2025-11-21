require('dotenv').config();
const http = require('http');
const { createApp } = require('./src/app');

const port = process.env.PORT || 3000;
const app = createApp();

function startServer() {
  const server = http.createServer(app);
  server.listen(port, () => {
    console.log(`Server listening on port ${port}`);
  });
  return server;
}

if (require.main === module) {
  startServer();
}

module.exports = { app, startServer };
