
import { Readability } from '@mozilla/readability';

import { JSDOM } from 'jsdom';

var site = "";
const decoder = new TextDecoder();
for await (const chunk of Deno.stdin.readable) {
  const text = decoder.decode(chunk);
  site += text;
}

// JSDOM.fromURL("https://github.com/koaning/smartfunc", { runScripts: "dangerously", }).then(dom => {
//   const reader = new Readability(dom.window.document);
//   const article = reader.parse();
//   console.log(article["content"]);
// });

const dom = new JSDOM(site, { runScripts: "dangerously" });
const reader = new Readability(dom.window.document);
const article = reader.parse();
console.log(article["content"]);
