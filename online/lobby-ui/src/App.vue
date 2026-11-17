<script setup>
import { onMounted, ref } from 'vue';
import { api } from './api.js';
import { t, toggleLang, lang } from './i18n.js';
import LoginView from './LoginView.vue';
import RoomsView from './RoomsView.vue';

const me = ref(null);
const ready = ref(false);

onMounted(async () => {
  document.documentElement.lang = lang.value;
  try {
    me.value = await api.me();
  } catch {
    me.value = null;
  }
  ready.value = true;
});

async function logout() {
  try {
    await api.logout();
  } finally {
    me.value = null;
  }
}
</script>

<template>
  <header class="top">
    <div class="brand">
      <img src="/favicon.svg" alt="" width="32" height="32" />
      <div>
        <h1>{{ t('title') }}</h1>
        <p class="muted">{{ t('tagline') }}</p>
      </div>
    </div>
    <div class="top-actions">
      <span v-if="me" class="muted who">{{ t('loggedInAs', { name: me.name }) }}</span>
      <button class="ghost" type="button" @click="toggleLang">{{ t('switchTo') }}</button>
      <button v-if="me" class="ghost" type="button" @click="logout">{{ t('logout') }}</button>
    </div>
  </header>
  <main v-if="ready">
    <LoginView v-if="!me" @logged-in="me = $event" />
    <RoomsView v-else :me="me" @logged-out="me = null" />
  </main>
</template>
