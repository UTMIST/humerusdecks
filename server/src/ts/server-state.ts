import { Cache } from "./cache";
import * as caches from "./caches";
import * as Config from "./config";
import { SocketManager } from "./socket-manager";
import { Store } from "./store";
import * as Stores from "./store/stores";
import * as Tasks from "./task/tasks";

export interface ServerState {
  config: Config.Parsed;
  store: Store;
  cache: Cache;
  socketManager: SocketManager;
  tasks: Tasks.Queue;
}

export async function create(config: Config.Parsed): Promise<ServerState> {
  const store = await Stores.from(config.storage);
  const cache = await caches.from(config.cache);
  const socketManager = new SocketManager();
  const tasks = new Tasks.Queue(config.tasks.rateLimit);

  return {
    config,
    store,
    cache,
    socketManager,
    tasks
  };
}
