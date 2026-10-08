import app from './app';
import { env } from './config/env';

const server = app.listen(env.PORT, () => {
  console.log(`Server running on port ${env.PORT} in ${env.NODE_ENV} mode`);
  console.log(`API available at http://localhost:${env.PORT}/api/${env.API_VERSION}`);
});

process.on('SIGINT', () => {
  console.log('Shutting down gracefully...');
  server.close();
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('Shutting down gracefully...');
  server.close();
  process.exit(0);
});

export default server;
