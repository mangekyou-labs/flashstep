// Snapshot the committed brand book at call time. Call at process start, before any write.
import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

export function committedBrandBook(root) {
  const path = fileURLToPath(new URL("packages/nextjs/public/brand.json", root));
  const text = readFileSync(path, "utf8");
  return {
    text,
    write(book) {
      writeFileSync(path, `${JSON.stringify(book, null, 2)}\n`);
    },
    restore() {
      writeFileSync(path, text);
    },
  };
}
