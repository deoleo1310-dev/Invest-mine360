// src/lib/dataCache.js
// Cache de datos con TTL y deduplicación de requests
// Extraído de Dashboard.jsx para reutilizarlo en toda la app

class DataCache {
  constructor(ttl = 30000) {
    this.cache = new Map();
    this.pendingRequests = new Map();
    this.ttl = ttl;
  }

  get(key) {
    const cached = this.cache.get(key);
    if (!cached) return null;

    if (Date.now() - cached.timestamp > this.ttl) {
      this.cache.delete(key);
      return null;
    }

    return cached.data;
  }

  set(key, data) {
    this.cache.set(key, { data, timestamp: Date.now() });
  }

  async getOrFetch(key, fetchFn) {
    const cached = this.get(key);
    if (cached) return cached;

    // Deduplicar requests concurrentes al mismo key
    if (this.pendingRequests.has(key)) {
      return this.pendingRequests.get(key);
    }

    const promise = fetchFn()
      .then(data => {
        this.set(key, data);
        this.pendingRequests.delete(key);
        return data;
      })
      .catch(err => {
        this.pendingRequests.delete(key);
        throw err;
      });

    this.pendingRequests.set(key, promise);
    return promise;
  }

  invalidate(key) {
    this.cache.delete(key);
    this.pendingRequests.delete(key);
  }

  invalidateAll() {
    this.cache.clear();
    this.pendingRequests.clear();
  }
}

// Instancias globales de cache reutilizables
export const clientCache = new DataCache(30000);   // 30s TTL
export const withdrawalCache = new DataCache(300000); // 5min TTL

export default DataCache;
