<script setup>
import { ref } from 'vue';
import { api } from './api.js';
import { t, errorText } from './i18n.js';

const emit = defineEmits(['logged-in']);
const name = ref('');
const code = ref('');
const error = ref('');
const busy = ref(false);

async function submit() {
  if (busy.value) return;
  busy.value = true;
  error.value = '';
  try {
    emit('logged-in', await api.login(name.value, code.value));
  } catch (err) {
    error.value = err.code;
  } finally {
    code.value = '';
    busy.value = false;
  }
}
</script>

<template>
  <section class="panel narrow">
    <h2>{{ t('loginTitle') }}</h2>
    <form @submit.prevent="submit">
      <label>
        <span>{{ t('name') }}</span>
        <input v-model="name" autocomplete="username" maxlength="16" required />
      </label>
      <label>
        <span>{{ t('code') }}</span>
        <input v-model="code" type="password" autocomplete="current-password" maxlength="200" required />
      </label>
      <p v-if="error" class="error" role="alert">{{ errorText(error) }}</p>
      <button class="primary" type="submit" :disabled="busy">{{ t('login') }}</button>
    </form>
  </section>
</template>
