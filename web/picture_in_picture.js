(function () {
  const mediaKitInstancesKey = "$com.alexmercerind.media_kit.instances";
  const bindings = new Map();

  function videoFor(handle) {
    const instances = globalThis[mediaKitInstancesKey];
    const exact = instances && instances[handle];
    if (exact instanceof HTMLVideoElement) return exact;

    // A fallback is useful while media_kit is completing its platform-view
    // registration, but never select a detached element.
    return Array.from(document.querySelectorAll("video")).find(
      (video) => video.isConnected
    ) || null;
  }

  function restoreVideo(video) {
    // Chromium can leave the platform view on a stale compositor layer after
    // the user closes the native PiP window. A one-frame layer refresh returns
    // it to Flutter without reloading the media or losing playback position.
    const previousTransform = video.style.transform;
    video.style.transform = "translateZ(0)";
    void video.offsetHeight;
    requestAnimationFrame(() => {
      if (video.isConnected) video.style.transform = previousTransform;
    });
  }

  function detach(handle) {
    const binding = bindings.get(handle);
    if (!binding) return;
    binding.video.removeEventListener("enterpictureinpicture", binding.enter);
    binding.video.removeEventListener("leavepictureinpicture", binding.leave);
    bindings.delete(handle);
  }

  globalThis.sabuflixPip = {
    isSupported(handle) {
      const video = videoFor(handle);
      return Boolean(
        document.pictureInPictureEnabled &&
        video &&
        typeof video.requestPictureInPicture === "function"
      );
    },

    isActive(handle) {
      return document.pictureInPictureElement === videoFor(handle);
    },

    attach(handle, callback) {
      detach(handle);
      const video = videoFor(handle);
      if (!video) return;

      video.disablePictureInPicture = false;
      const enter = () => callback(true);
      const leave = () => {
        restoreVideo(video);
        if (video.dataset.sabuflixPipWasPlaying === "true" && video.paused) {
          video.play().catch(() => {});
        }
        callback(false);
      };
      video.addEventListener("enterpictureinpicture", enter);
      video.addEventListener("leavepictureinpicture", leave);
      bindings.set(handle, { video, enter, leave });
      callback(document.pictureInPictureElement === video);
    },

    async enter(handle) {
      const video = videoFor(handle);
      if (!video || !this.isSupported(handle)) return false;
      if (document.pictureInPictureElement === video) return true;
      if (document.pictureInPictureElement) {
        await document.exitPictureInPicture();
      }
      video.dataset.sabuflixPipWasPlaying = String(!video.paused);
      await video.requestPictureInPicture();
      return true;
    },

    async exit(handle) {
      const video = videoFor(handle);
      if (video && document.pictureInPictureElement === video) {
        await document.exitPictureInPicture();
        restoreVideo(video);
      }
      return false;
    },

    detach,
  };
})();
