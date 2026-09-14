import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import vm from 'node:vm';

const source = await readFile(new URL('../client/gamepad-compat.js', import.meta.url), 'utf8');

test('standard extra axes cannot overwrite triggers; native getters and live state survive', () => {
  class Pad {
    #id = 'Third-party gamepad';
    mapping = 'standard';
    axes = [0.2, -0.3, 0, 0, 0, 0];
    buttons = Array(17).fill({ value: 0 });
    get id() { return this.#id; }
  }
  const pad = new Pad();
  pad.buttons[6] = { value: 0.8 };
  let pads = [null, pad];
  const navigator = { getGamepads() { assert.equal(this, navigator); return pads; } };
  vm.runInNewContext(source, { navigator });
  const first = navigator.getGamepads();
  assert.equal(first[0], null);
  assert.deepEqual(first[1].axes, [0.2, -0.3, 0, 0]);
  assert.equal(first[1].id, 'Third-party gamepad');
  assert.equal(first[1].buttons[6].value, 0.8);
  assert.equal(pad.axes.length, 6);
  pad.axes[0] = 0.9;
  assert.equal(navigator.getGamepads()[1].axes[0], 0.9);
  pads = [null, null];
  assert.equal(navigator.getGamepads()[1], null);
});

test('four-axis standard pads and unknown mappings retain their original objects', () => {
  const standard = { mapping: 'standard', axes: [0, 0, 0, 0] };
  const unknown = { mapping: '', axes: [0, 0, 0, 0, -1, -1] };
  const navigator = { getGamepads: () => [standard, unknown] };
  vm.runInNewContext(source, { navigator });
  assert.equal(navigator.getGamepads()[0], standard);
  assert.equal(navigator.getGamepads()[1], unknown);
});

test('a browser without the Gamepad API still starts normally', () => {
  vm.runInNewContext(source, { navigator: {} });
});
