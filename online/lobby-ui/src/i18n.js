// English + Greek, like the game (MANIFEST constraint 5): the page shows one
// language at a time, switched with the language button, remembered per browser.
import { ref } from 'vue';

const STRINGS = {
  en: {
    title: 'board2D',
    tagline: 'Online rooms',
    switchTo: 'Ελληνικά',
    logout: 'Log out',
    loginTitle: 'Who are you?',
    name: 'Name',
    code: 'Access code',
    login: 'Enter',
    loggedInAs: 'Playing as {name}',
    newRoom: 'New room',
    roomTitle: 'Room name (optional)',
    open: 'Open',
    openHint: 'Listed here for everyone',
    private: 'Private',
    privateHint: 'Join by code only',
    maxPlayers: 'Players',
    create: 'Create room',
    joinByCode: 'Join with a code',
    roomCode: 'Room code',
    join: 'Join',
    rooms: 'Rooms',
    noRooms: 'No rooms yet. Make one, or join a friend’s with its code.',
    owner: 'Owner: {name}',
    waiting: 'Waiting',
    playing: 'Playing',
    starting: 'Starting…',
    players: '{n} / {max} players',
    playBrowser: 'Play in browser',
    desktopLink: 'Desktop link',
    desktopCopied: 'Copied! Paste it into the game’s Join box within a minute.',
    desktopShow: 'Paste this into the desktop game’s Join box within a minute:',
    makeOpen: 'Make open',
    makePrivate: 'Make private',
    close: 'Close room',
    closeConfirm: 'Close this room for everyone in it?',
    copyCode: 'Copy code',
    copied: 'Copied!',
    yours: 'Your room',
    desktopTitle: 'Desktop game (Windows)',
    desktopIntro: 'Rather play in a window of its own? Download it, nothing to install.',
    download: 'Download for Windows',
    downloadSize: 'Download for Windows ({size} MB)',
    desktopStep1: 'Unzip it and open board2D.exe.',
    desktopStep2: 'If Windows says “Windows protected your PC”: More info → Run anyway. (The game isn’t signed, that’s all.)',
    desktopStep3: 'Here, press “Desktop link” on a room. In the game, paste it into “Host’s code or room link” and press Join.',
    errors: {
      wrong_name_or_code: 'That name and code don’t match.',
      too_many_attempts: 'Too many tries. Wait a few minutes.',
      not_logged_in: 'Please log in again.',
      too_many_rooms: 'The server is full right now. Try again later.',
      you_have_a_room: 'You already have a room. Close it first.',
      room_failed_to_start: 'The room couldn’t start. Try again.',
      no_such_room: 'No room with that code.',
      room_full: 'That room is full.',
      room_playing: 'That room is in the middle of a game.',
      room_starting: 'That room is still starting. Try again in a moment.',
      already_in_room: 'You’re already in that room.',
      not_your_room: 'Only the room’s owner can do that.',
      slow_down: 'Slow down a little.',
      network: 'Can’t reach the server.',
      unknown: 'Something went wrong.',
    },
  },
  el: {
    title: 'board2D',
    tagline: 'Online δωμάτια',
    switchTo: 'English',
    logout: 'Αποσύνδεση',
    loginTitle: 'Ποιος είσαι;',
    name: 'Όνομα',
    code: 'Κωδικός πρόσβασης',
    login: 'Είσοδος',
    loggedInAs: 'Παίζεις ως {name}',
    newRoom: 'Νέο δωμάτιο',
    roomTitle: 'Όνομα δωματίου (προαιρετικό)',
    open: 'Ανοιχτό',
    openHint: 'Φαίνεται εδώ σε όλους',
    private: 'Ιδιωτικό',
    privateHint: 'Μόνο με κωδικό',
    maxPlayers: 'Παίκτες',
    create: 'Δημιουργία',
    joinByCode: 'Μπες με κωδικό',
    roomCode: 'Κωδικός δωματίου',
    join: 'Μπες',
    rooms: 'Δωμάτια',
    noRooms: 'Δεν υπάρχουν δωμάτια ακόμα. Φτιάξε ένα ή μπες σε φίλου με τον κωδικό του.',
    owner: 'Ιδιοκτήτης: {name}',
    waiting: 'Αναμονή',
    playing: 'Σε παιχνίδι',
    starting: 'Ξεκινά…',
    players: '{n} / {max} παίκτες',
    playBrowser: 'Παίξε στον browser',
    desktopLink: 'Σύνδεσμος για desktop',
    desktopCopied: 'Αντιγράφηκε! Επικόλλησέ τον στο «Σύνδεση» του παιχνιδιού μέσα σε ένα λεπτό.',
    desktopShow: 'Επικόλλησε αυτό στο «Σύνδεση» του desktop παιχνιδιού μέσα σε ένα λεπτό:',
    makeOpen: 'Κάν’ το ανοιχτό',
    makePrivate: 'Κάν’ το ιδιωτικό',
    close: 'Κλείσιμο',
    closeConfirm: 'Να κλείσει το δωμάτιο για όλους;',
    copyCode: 'Αντιγραφή κωδικού',
    copied: 'Αντιγράφηκε!',
    yours: 'Δικό σου',
    desktopTitle: 'Παιχνίδι για υπολογιστή (Windows)',
    desktopIntro: 'Το θες σε δικό του παράθυρο; Κατέβασέ το, χωρίς εγκατάσταση.',
    download: 'Λήψη για Windows',
    downloadSize: 'Λήψη για Windows ({size} MB)',
    desktopStep1: 'Αποσυμπίεσέ το και άνοιξε το board2D.exe.',
    desktopStep2: 'Αν τα Windows πουν «Τα Windows προστάτευσαν τον υπολογιστή σας»: Περισσότερες πληροφορίες → Εκτέλεση οπωσδήποτε. (Απλώς το παιχνίδι δεν είναι υπογεγραμμένο.)',
    desktopStep3: 'Εδώ, πάτα «Σύνδεσμος για desktop» σε ένα δωμάτιο. Στο παιχνίδι, επικόλλησέ τον στο «Κωδικός οικοδεσπότη ή σύνδεσμος δωματίου» και πάτα «Σύνδεση».',
    errors: {
      wrong_name_or_code: 'Το όνομα και ο κωδικός δεν ταιριάζουν.',
      too_many_attempts: 'Πάρα πολλές προσπάθειες. Περίμενε λίγα λεπτά.',
      not_logged_in: 'Συνδέσου ξανά.',
      too_many_rooms: 'Ο server είναι γεμάτος. Δοκίμασε αργότερα.',
      you_have_a_room: 'Έχεις ήδη δωμάτιο. Κλείσ’ το πρώτα.',
      room_failed_to_start: 'Το δωμάτιο δεν ξεκίνησε. Δοκίμασε ξανά.',
      no_such_room: 'Δεν υπάρχει δωμάτιο με αυτόν τον κωδικό.',
      room_full: 'Το δωμάτιο είναι γεμάτο.',
      room_playing: 'Το δωμάτιο είναι στη μέση παιχνιδιού.',
      room_starting: 'Το δωμάτιο ακόμα ξεκινά. Δοκίμασε σε λίγο.',
      already_in_room: 'Είσαι ήδη σε αυτό το δωμάτιο.',
      not_your_room: 'Μόνο ο ιδιοκτήτης του δωματίου μπορεί.',
      slow_down: 'Πιο αργά λίγο.',
      network: 'Δεν βρίσκω τον server.',
      unknown: 'Κάτι πήγε στραβά.',
    },
  },
};

function savedLang() {
  try {
    const v = localStorage.getItem('b2d_lang');
    if (v === 'en' || v === 'el') return v;
  } catch {
    /* storage blocked: fall through */
  }
  return navigator.language?.startsWith('el') ? 'el' : 'en';
}

export const lang = ref(savedLang());

export function toggleLang() {
  lang.value = lang.value === 'en' ? 'el' : 'en';
  try {
    localStorage.setItem('b2d_lang', lang.value);
  } catch {
    /* not saved: fine */
  }
  document.documentElement.lang = lang.value;
}

export function t(key, params = {}) {
  const table = STRINGS[lang.value];
  const text = key.split('.').reduce((o, k) => (o ? o[k] : undefined), table) ?? key;
  return String(text).replace(/\{(\w+)\}/g, (_, p) => (p in params ? params[p] : `{${p}}`));
}

export function errorText(code) {
  const table = STRINGS[lang.value].errors;
  return table[code] ?? table.unknown;
}
