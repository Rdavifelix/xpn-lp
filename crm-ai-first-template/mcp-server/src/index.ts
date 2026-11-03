import { readConfig } from './auth.js';
import { createApp } from './app.js';

const config = readConfig(process.env);
const server = createApp(config).listen(config.port, config.host, () => {
  console.log(`CRM MCP escutando em ${config.host}:${config.port}. OAuth: ${config.publicUrl}`);
});
for (const signal of ['SIGINT', 'SIGTERM']) process.on(signal, () => server.close());
