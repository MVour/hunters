// Talks to the lobby service (online/lobby-service/src/app.js). Same origin,
// cookie session; errors come back as Error with .code (translated by the page).

async function call(method, path, body) {
  let res;
  try {
    res = await fetch(path, {
      method,
      credentials: 'same-origin',
      headers: body === undefined ? {} : { 'Content-Type': 'application/json' },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
  } catch {
    throw Object.assign(new Error('network'), { code: 'network' });
  }
  let data = {};
  try {
    data = await res.json();
  } catch {
    /* empty or not JSON */
  }
  if (!res.ok) throw Object.assign(new Error(data.error || 'unknown'), { code: data.error || 'unknown', status: res.status });
  return data;
}

export const api = {
  me: () => call('GET', '/api/me'),
  login: (name, code) => call('POST', '/api/login', { name, code }),
  logout: () => call('POST', '/api/logout', {}),
  rooms: () => call('GET', '/api/rooms'),
  createRoom: (room) => call('POST', '/api/rooms', room),
  join: (code) => call('POST', `/api/rooms/${encodeURIComponent(code)}/join`, {}),
  setVisibility: (code, visibility) => call('PATCH', `/api/rooms/${encodeURIComponent(code)}`, { visibility }),
  close: (code) => call('DELETE', `/api/rooms/${encodeURIComponent(code)}`),
};
