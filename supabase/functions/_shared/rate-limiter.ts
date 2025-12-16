// supabase/functions/_shared/rate-limiter.ts

interface RateLimitConfig {
  maxRequests: number;
  windowMs: number;
  identifier: string; // user_id, ip, etc
}

class RateLimiter {
  private requests: Map<string, number[]> = new Map();

  check(config: RateLimitConfig): { allowed: boolean; remaining: number } {
    const now = Date.now();
    const windowStart = now - config.windowMs;
    
    // Obtener requests del usuario en la ventana actual
    const userRequests = this.requests.get(config.identifier) || [];
    
    // Filtrar requests antiguos
    const validRequests = userRequests.filter(timestamp => timestamp > windowStart);
    
    // Verificar límite
    const allowed = validRequests.length < config.maxRequests;
    
    if (allowed) {
      validRequests.push(now);
      this.requests.set(config.identifier, validRequests);
    }
    
    return {
      allowed,
      remaining: Math.max(0, config.maxRequests - validRequests.length)
    };
  }

  // Limpiar requests antiguos (ejecutar periódicamente)
  cleanup() {
    const now = Date.now();
    for (const [key, timestamps] of this.requests.entries()) {
      const valid = timestamps.filter(t => t > now - 3600000); // 1 hora
      if (valid.length === 0) {
        this.requests.delete(key);
      } else {
        this.requests.set(key, valid);
      }
    }
  }
}

// Instancia global
export const rateLimiter = new RateLimiter();

// Ejecutar cleanup cada 5 minutos
setInterval(() => rateLimiter.cleanup(), 300000);

// Helper para verificar rate limit
export function checkRateLimit(
  userId: string,
  maxRequests: number = 10,
  windowMs: number = 60000 // 1 minuto
) {
  return rateLimiter.check({
    maxRequests,
    windowMs,
    identifier: userId
  });
}