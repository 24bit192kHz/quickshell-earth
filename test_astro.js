const fs = require('fs');
const code = fs.readFileSync('core/astronomy.js', 'utf8').replace('.pragma library', '');
eval(code);
let ms = Date.now();
let astro = calculateAstronomy(ms, 0, "saturn");
console.log("Sun Dec:", astro.sun_dec * 180 / Math.PI, "degrees");
