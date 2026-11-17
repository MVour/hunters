// In-memory rate limits. One process serves a friends' game, so memory is
// enough; old entries are swept every minute.

export class WindowCounter {
  constructor(limit, windowMs) {
    this.limit = limit;
    this.windowMs = windowMs;
    this.hits = new Map(); // key -> { count, resetAt }
  }

  /** Counts a hit; false if the key is over its limit. */
  hit(key, now = Date.now()) {
    let entry = this.hits.get(key);
    if (!entry || entry.resetAt <= now) {
      entry = { count: 0, resetAt: now + this.windowMs };
      this.hits.set(key, entry);
    }
    entry.count += 1;
    return entry.count <= this.limit;
  }

  /** Over the limit already (without counting a new hit)? */
  blocked(key, now = Date.now()) {
    const entry = this.hits.get(key);
    return !!entry && entry.resetAt > now && entry.count >= this.limit;
  }

  reset(key) {
    this.hits.delete(key);
  }

  sweep(now = Date.now()) {
    for (const [key, entry] of this.hits) if (entry.resetAt <= now) this.hits.delete(key);
  }
}

/** Token bucket for messages on one connection. */
export class TokenBucket {
  constructor(perSecond, burst = perSecond * 2) {
    this.perSecond = perSecond;
    this.capacity = burst;
    this.tokens = burst;
    this.last = Date.now();
  }

  take(now = Date.now()) {
    this.tokens = Math.min(this.capacity, this.tokens + ((now - this.last) / 1000) * this.perSecond);
    this.last = now;
    if (this.tokens < 1) return false;
    this.tokens -= 1;
    return true;
  }
}
