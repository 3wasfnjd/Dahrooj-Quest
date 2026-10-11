// Browser-only regression fixture. Bundled in memory by test-browser.mjs; never shipped in APK.
import {GLTFLoader} from 'three/addons/loaders/GLTFLoader.js';
import {SRGBColorSpace} from 'three';

export async function inspectBundledMaterials(names) {
  const models = [];
  for (const name of names) {
    const gltf = await new GLTFLoader().loadAsync(`/assets/models/${name}`);
    const materials = [];
    for (const [index, definition] of gltf.parser.json.materials.entries()) {
      if (!definition.pbrMetallicRoughness?.baseColorTexture) continue;
      const material = await gltf.parser.getDependency('material', index);
      const map = material.map;
      const image = map?.image;
      const result = {name:definition.name, hasMap:!!map, imageBitmap:image instanceof ImageBitmap,
        width:image?.width || 0, height:image?.height || 0, srgb:map?.colorSpace === SRGBColorSpace,
        nonBlackPixels:0, uniqueColors:0};
      if (image) {
        const canvas = document.createElement('canvas');
        canvas.width = image.width; canvas.height = image.height;
        const context = canvas.getContext('2d', {willReadFrequently:true});
        context.drawImage(image, 0, 0);
        const pixels = context.getImageData(0, 0, canvas.width, canvas.height).data;
        const colors = new Set();
        for (let p = 0; p < pixels.length; p += 4) {
          colors.add(Array.from(pixels.subarray(p, p + 4)).join(','));
          if (pixels[p + 3] > 0 && Math.max(pixels[p], pixels[p + 1], pixels[p + 2]) > 0)
            result.nonBlackPixels++;
        }
        result.uniqueColors = colors.size;
      }
      materials.push(result);
    }
    models.push({name, materials});
    gltf.scene.traverse(object => {
      object.geometry?.dispose();
      for (const material of [object.material].flat().filter(Boolean)) {
        material.map?.dispose(); material.dispose();
      }
    });
  }
  return models;
}
