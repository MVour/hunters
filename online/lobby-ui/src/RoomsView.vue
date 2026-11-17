<script setup>
import { computed, onMounted, onUnmounted, ref } from 'vue';
import { api } from './api.js';
import { t, errorText } from './i18n.js';

const props = defineProps({ me: { type: Object, required: true } });
const emit = defineEmits(['logged-out']);

const rooms = ref([]);
const maxAllowed = ref(8);
const error = ref('');
const notice = ref('');
const desktopLink = ref('');
const busy = ref(false);

const newTitle = ref('');
const newVisibility = ref('private');
const newMax = ref(8);
const joinCode = ref('');

const playerChoices = computed(() => Array.from({ length: maxAllowed.value - 1 }, (_, i) => i + 2));

let timer;
async function refresh() {
  try {
    const data = await api.rooms();
    rooms.value = data.rooms.sort((a, b) => Number(b.mine) - Number(a.mine) || a.createdAt - b.createdAt);
    maxAllowed.value = data.maxPlayers;
    if (newMax.value > data.maxPlayers) newMax.value = data.maxPlayers;
  } catch (err) {
    if (err.status === 401) emit('logged-out');
  }
}
onMounted(() => {
  refresh();
  timer = setInterval(refresh, 4000);
});
onUnmounted(() => clearInterval(timer));

async function act(fn) {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  notice.value = '';
  try {
    await fn();
  } catch (err) {
    error.value = err.code;
    if (err.status === 401) emit('logged-out');
  } finally {
    busy.value = false;
    refresh();
  }
}

const create = () => act(async () => {
  await api.createRoom({ title: newTitle.value, visibility: newVisibility.value, maxPlayers: newMax.value });
  newTitle.value = '';
});

/** Into the browser game: the ticket rides in the #fragment (never sent to a server). */
const play = (code) => act(async () => {
  const { code: room, ticket } = await api.join(code);
  window.location.assign(`/game/#room=${encodeURIComponent(room)}&ticket=${encodeURIComponent(ticket)}`);
});

const joinWithCode = () => {
  const code = joinCode.value.trim().toUpperCase();
  if (code) play(code);
};

/** A link for the desktop game's Join box (single use, valid a minute). */
const desktop = (code) => act(async () => {
  const { path } = await api.join(code);
  const link = `${location.protocol === 'https:' ? 'wss' : 'ws'}://${location.host}${path}`;
  desktopLink.value = '';
  try {
    await navigator.clipboard.writeText(link);
    notice.value = t('desktopCopied');
  } catch {
    desktopLink.value = link; // no clipboard access: show it to copy by hand
  }
});

const toggleVisibility = (room) => act(() => api.setVisibility(room.code, room.visibility === 'open' ? 'private' : 'open'));

const close = (room) => {
  if (window.confirm(t('closeConfirm'))) act(() => api.close(room.code));
};

const copied = ref('');
async function copyCode(code) {
  try {
    await navigator.clipboard.writeText(code);
    copied.value = code;
    setTimeout(() => { copied.value = ''; }, 1500);
  } catch {
    /* the code is on screen anyway */
  }
}

const canManage = (room) => room.mine || props.me.admin;
</script>

<template>
  <p v-if="error" class="error banner" role="alert">{{ errorText(error) }}</p>
  <p v-if="notice" class="notice banner" role="status">{{ notice }}</p>
  <div v-if="desktopLink" class="panel">
    <p>{{ t('desktopShow') }}</p>
    <input class="link" readonly :value="desktopLink" @focus="$event.target.select()" />
  </div>

  <div class="columns">
    <section class="panel">
      <h2>{{ t('newRoom') }}</h2>
      <form @submit.prevent="create">
        <label>
          <span>{{ t('roomTitle') }}</span>
          <input v-model="newTitle" maxlength="32" />
        </label>
        <fieldset class="segmented">
          <label :class="{ on: newVisibility === 'private' }">
            <input v-model="newVisibility" type="radio" value="private" />
            <strong>{{ t('private') }}</strong><small>{{ t('privateHint') }}</small>
          </label>
          <label :class="{ on: newVisibility === 'open' }">
            <input v-model="newVisibility" type="radio" value="open" />
            <strong>{{ t('open') }}</strong><small>{{ t('openHint') }}</small>
          </label>
        </fieldset>
        <label>
          <span>{{ t('maxPlayers') }}</span>
          <select v-model.number="newMax">
            <option v-for="n in playerChoices" :key="n" :value="n">{{ n }}</option>
          </select>
        </label>
        <button class="primary" type="submit" :disabled="busy">{{ t('create') }}</button>
      </form>

      <h2 class="spaced">{{ t('joinByCode') }}</h2>
      <form class="row" @submit.prevent="joinWithCode">
        <input v-model="joinCode" :placeholder="t('roomCode')" maxlength="16" autocapitalize="characters" spellcheck="false" />
        <button class="primary" type="submit" :disabled="busy || !joinCode.trim()">{{ t('join') }}</button>
      </form>
    </section>

    <section class="panel grow">
      <h2>{{ t('rooms') }}</h2>
      <p v-if="rooms.length === 0" class="muted">{{ t('noRooms') }}</p>
      <ul class="rooms">
        <li v-for="room in rooms" :key="room.code" class="room" :class="{ mine: room.mine }">
          <div class="room-head">
            <div>
              <h3>{{ room.title }}</h3>
              <p class="muted">{{ t('owner', { name: room.owner }) }}</p>
            </div>
            <button class="code" type="button" :title="t('copyCode')" @click="copyCode(room.code)">
              {{ copied === room.code ? t('copied') : room.code }}
            </button>
          </div>
          <p class="tags">
            <span v-if="room.mine" class="tag gold">{{ t('yours') }}</span>
            <span class="tag">{{ room.visibility === 'open' ? t('open') : t('private') }}</span>
            <span class="tag" :class="room.inMatch ? 'red' : 'green'">
              {{ room.state !== 'ready' ? t('starting') : room.inMatch ? t('playing') : t('waiting') }}
            </span>
            <span class="tag">{{ t('players', { n: room.players.length, max: room.maxPlayers }) }}</span>
          </p>
          <p v-if="room.players.length" class="muted small">{{ room.players.join(' · ') }}</p>
          <div class="actions">
            <button class="primary" type="button" :disabled="busy || room.inMatch || room.state !== 'ready'" @click="play(room.code)">
              {{ t('playBrowser') }}
            </button>
            <button type="button" :disabled="busy || room.inMatch || room.state !== 'ready'" @click="desktop(room.code)">
              {{ t('desktopLink') }}
            </button>
            <template v-if="canManage(room)">
              <button class="ghost" type="button" :disabled="busy" @click="toggleVisibility(room)">
                {{ room.visibility === 'open' ? t('makePrivate') : t('makeOpen') }}
              </button>
              <button class="danger" type="button" :disabled="busy" @click="close(room)">{{ t('close') }}</button>
            </template>
          </div>
        </li>
      </ul>
    </section>
  </div>
</template>
