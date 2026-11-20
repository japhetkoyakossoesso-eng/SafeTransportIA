import '@fontsource-variable/inter';
import '@fontsource-variable/manrope';
import { createApp } from 'vue';
import App from './App.vue';
import { routeur } from './routeur.js';
import './theme.js';
import './style.css';

createApp(App).use(routeur).mount('#app');
