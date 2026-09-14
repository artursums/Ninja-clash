(() => {
  if (typeof navigator.getGamepads !== 'function') return;
  const getGamepads = navigator.getGamepads.bind(navigator);

  // Godot 4.6.2 copies extra standard axes over the LT/RT values derived from buttons 6/7.
  // https://github.com/godotengine/godot/blob/4.6.2-stable/platform/web/display_server_web.cpp#L899-L925
  Object.defineProperty(navigator, 'getGamepads', {
    configurable: true,
    writable: true,
    value() {
      return Array.from(getGamepads(), pad => {
        if (!pad || pad.mapping !== 'standard' || pad.axes.length <= 4) return pad;
        return new Proxy(pad, {
          get(target, property) {
            if (property === 'axes') return target.axes.slice(0, 4);
            return Reflect.get(target, property, target);
          },
        });
      });
    },
  });
})();
