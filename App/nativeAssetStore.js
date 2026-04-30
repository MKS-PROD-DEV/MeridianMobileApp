 (function () {
   const { Filesystem, Directory } = Capacitor.Plugins;
   const { Preferences } = Capacitor.Plugins;

   function assetDir(assetId) {
     return `assets/${assetId}`;
   }

   function guessExt(url) {
     const clean = url.split("?")[0];
     const parts = clean.split(".");
     const ext = parts.length > 1 ? parts.pop() : null;
     return ext && ext.length < 8 ? ext : "bin";
   }

   function blobToBase64(blob) {
     return new Promise((resolve, reject) => {
       const reader = new FileReader();
       reader.onerror = () => reject(reader.error);
       reader.onload = () => {
         const dataUrl = String(reader.result); // data:*/*;base64,....
         resolve(dataUrl.split(",")[1]);
       };
       reader.readAsDataURL(blob);
     });
   }

   async function downloadAsset(params) {
     const assetId = params.assetId;
     const url = params.url;
     const filename = params.filename || `original.${guessExt(url)}`;

     const resp = await fetch(url);
     if (!resp.ok) throw new Error(`Download failed: ${resp.status}`);
     const blob = await resp.blob();

     const base64 = await blobToBase64(blob);

     const dir = assetDir(assetId);
     await Filesystem.mkdir({ directory: Directory.Documents, path: dir, recursive: true });

     const path = `${dir}/${filename}`;
     await Filesystem.writeFile({
       directory: Directory.Documents,
       path,
       data: base64,
       recursive: true,
     });

     const meta = Object.assign(
       {
         assetId,
         url,
         filename,
         path,
         mimeType: blob.type || null,
         size: blob.size,
         downloadedAt: new Date().toISOString(),
       },
       params.meta || {}
     );

     await Preferences.set({
       key: `asset:${assetId}:meta`,
       value: JSON.stringify(meta),
     });

     return meta;
   }

   async function getAssetMeta(assetId) {
     const { value } = await Preferences.get({ key: `asset:${assetId}:meta` });
     return value ? JSON.parse(value) : null;
   }

   async function saveProgress(assetId, progress) {
     await Preferences.set({
       key: `asset:${assetId}:progress`,
       value: JSON.stringify(Object.assign({}, progress, { updatedAt: new Date().toISOString() })),
     });
   }

   async function getProgress(assetId) {
     const { value } = await Preferences.get({ key: `asset:${assetId}:progress` });
     return value ? JSON.parse(value) : null;
   }

   async function setLastLaunchState(state) {
     await Preferences.set({
       key: `app:lastLaunchState`,
       value: JSON.stringify(Object.assign({}, state, { updatedAt: new Date().toISOString() })),
     });
   }

   async function getLastLaunchState() {
     const { value } = await Preferences.get({ key: `app:lastLaunchState` });
     return value ? JSON.parse(value) : null;
   }

   // Expose a simple global API
   window.NativeAssetStore = {
     downloadAsset,
     getAssetMeta,
     saveProgress,
     getProgress,
     setLastLaunchState,
     getLastLaunchState,
   };
 })();
