import fs from "node:fs";
import path from "node:path";

import { notFound } from "next/navigation";
import type { CSSProperties } from "react";

import { StitchIconHydrator } from "./stitch-icon-hydrator";

const ACCENT_THEME_VARS = {
  "--color-primary": "#FE6132",
  "--color-background-light": "#FFFFFF",
  "--color-background-dark": "#1A0F0A",
} as CSSProperties;

function readStitchHtml(fileName: string) {
  const htmlPath = path.join(process.cwd(), "public", "stitch_pages", fileName);

  if (!fs.existsSync(htmlPath)) {
    notFound();
  }

  return fs.readFileSync(htmlPath, "utf8");
}

function escapeAttribute(value: string) {
  return value.replace(/&/g, "&amp;").replace(/\"/g, "&quot;");
}

function replaceMaterialSymbols(rawHtml: string) {
  return rawHtml.replace(
    /<span([^>]*class="[^"]*material-symbols-outlined[^"]*"[^>]*)>([\s\S]*?)<\/span>/gi,
    (_full, attrs: string, content: string) => {
      const classMatch = attrs.match(/\bclass\s*=\s*"([^"]*)"/i);
      const dataIconMatch = attrs.match(/\bdata-icon\s*=\s*"([^"]*)"/i);

      const iconName =
        (dataIconMatch?.[1] ??
          content.replace(/<[^>]*>/g, "").replace(/&nbsp;/g, " ").trim()) ||
        "circle";

      const className = (classMatch?.[1] ?? "")
        .split(/\s+/)
        .filter((item) => item && item !== "material-symbols-outlined")
        .join(" ");

      const retainedAttrs = attrs
        .replace(/\bclass\s*=\s*"[^"]*"/i, "")
        .replace(/\bdata-icon\s*=\s*"[^"]*"/i, "")
        .trim();

      const slotClassName = `stitch-icon-slot ${className}`.trim();
      const iconSlotAttrs = [
        retainedAttrs,
        `class="${escapeAttribute(slotClassName)}"`,
        `data-stitch-icon="${escapeAttribute(iconName.toLowerCase())}"`,
        'aria-hidden="true"',
      ]
        .filter(Boolean)
        .join(" ");

      return `<span ${iconSlotAttrs}></span>`;
    },
  );
}

function stripDarkModeClasses(rawHtml: string) {
  return rawHtml.replace(/\bclass\s*=\s*"([^"]*)"/gi, (_full, classValue: string) => {
    const sanitized = classValue
      .split(/\s+/)
      .filter((token) => token && token !== "dark" && !token.startsWith("dark:"))
      .join(" ");
    return `class="${sanitized}"`;
  });
}

function extractBody(rawHtml: string) {
  const match = rawHtml.match(/<body([^>]*)>([\s\S]*?)<\/body>/i);

  if (!match) {
    return { className: "", innerHtml: rawHtml };
  }

  const attrs = match[1] ?? "";
  const className = attrs.match(/class\s*=\s*"([^"]*)"/i)?.[1] ?? "";
  const innerHtml = match[2] ?? "";

  return { className, innerHtml };
}

function extractStyleBlocks(rawHtml: string) {
  const styles: string[] = [];
  const regex = /<style[^>]*>([\s\S]*?)<\/style>/gi;

  let styleMatch: RegExpExecArray | null = regex.exec(rawHtml);
  while (styleMatch) {
    const css = styleMatch[1]?.trim();
    if (css) {
      styles.push(css);
    }
    styleMatch = regex.exec(rawHtml);
  }

  return styles;
}

export function StitchPage({ fileName }: { fileName: string }) {
  const rawHtml = stripDarkModeClasses(
    replaceMaterialSymbols(readStitchHtml(fileName)),
  );
  const { className, innerHtml } = extractBody(rawHtml);
  const styles = extractStyleBlocks(rawHtml);

  return (
    <>
      {styles.map((css, index) => (
        <style
          // Styles are part of the imported static page payload.
          // eslint-disable-next-line react/no-danger
          dangerouslySetInnerHTML={{ __html: css }}
          key={`${fileName}-style-${index}`}
        />
      ))}
      <div
        className={`stitch-canvas ${className}`.trim()}
        // The HTML comes from checked-in stitch exports in this repository.
        // eslint-disable-next-line react/no-danger
        dangerouslySetInnerHTML={{ __html: innerHtml }}
        style={ACCENT_THEME_VARS}
      />
      <StitchIconHydrator />
    </>
  );
}
