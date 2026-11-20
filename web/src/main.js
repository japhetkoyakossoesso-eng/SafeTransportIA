import { createApp } from 'vue';
import App from './App.vue';
import { routeur } from './routeur.js';
import './style.css';

createApp(App).use(routeur).mount('#app');
