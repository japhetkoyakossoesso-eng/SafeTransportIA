import { describe, expect, it, vi } from 'vitest';
import { flushPromises, mount } from '@vue/test-utils';
import ServiceStatus from '../components/ServiceStatus.vue';

describe('ServiceStatus', () => {
  it('affiche le statut renvoyé par le service', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => ({ json: async () => ({ status: 'ok', database: 'pg 16' }) })));
    const wrapper = mount(ServiceStatus, { props: { name: 'API', url: '/api/v1/health' } });
    await flushPromises();
    expect(wrapper.find('.state').text()).toBe('ok');
  });

  it('signale un service injoignable', async () => {
    vi.stubGlobal('fetch', vi.fn(async () => { throw new Error('down'); }));
    const wrapper = mount(ServiceStatus, { props: { name: 'API', url: '/api/v1/health' } });
    await flushPromises();
    expect(wrapper.find('.state').text()).toBe('injoignable');
  });
});
