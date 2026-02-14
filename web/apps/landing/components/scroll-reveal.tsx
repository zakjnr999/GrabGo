"use client";

import { useEffect, useRef, useState, type CSSProperties, type ReactNode } from "react";

type ScrollRevealProps = {
  children: ReactNode;
  className?: string;
  delayMs?: number;
  threshold?: number;
};

export function ScrollReveal({
  children,
  className,
  delayMs = 0,
  threshold = 0.2,
}: ScrollRevealProps) {
  const elementRef = useRef<HTMLDivElement | null>(null);
  const [isVisible, setIsVisible] = useState(false);

  useEffect(() => {
    const current = elementRef.current;
    if (!current) {
      return;
    }

    const observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            setIsVisible(true);
            observer.unobserve(entry.target);
          }
        });
      },
      {
        threshold,
        rootMargin: "0px 0px -10% 0px",
      },
    );

    observer.observe(current);
    return () => observer.disconnect();
  }, [threshold]);

  const style = { "--reveal-delay": `${delayMs}ms` } as CSSProperties;
  const revealClass = isVisible ? "reveal reveal-visible" : "reveal";

  return (
    <div ref={elementRef} className={`${revealClass}${className ? ` ${className}` : ""}`} style={style}>
      {children}
    </div>
  );
}
