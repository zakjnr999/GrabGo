"use client";

import * as IconoirIcons from "iconoir-react";
import * as LucideIcons from "lucide-react";
import { usePathname } from "next/navigation";
import { type ComponentType, useEffect, useRef } from "react";
import { createRoot, type Root } from "react-dom/client";

type IconComponent = ComponentType<{
  className?: string;
  strokeWidth?: number;
  [key: string]: unknown;
}>;

type IconLibrary = Record<string, IconComponent>;

const ICONOIR_LIBRARY = IconoirIcons as unknown as IconLibrary;
const LUCIDE_LIBRARY = LucideIcons as unknown as IconLibrary;

const MATERIAL_ICON_MAP: Record<
  string,
  { iconoir?: string[]; lucide?: string[] }
> = {
  add_shopping_cart: { iconoir: ["Cart"], lucide: ["ShoppingCart"] },
  ads_click: { lucide: ["Megaphone", "Pointer"] },
  alternate_email: { lucide: ["AtSign", "Mail"] },
  analytics: { lucide: ["BarChart3", "LineChart"] },
  arrow_forward: { iconoir: ["NavArrowRight"], lucide: ["ArrowRight"] },
  arrow_upward: { lucide: ["ArrowUp"] },
  auto_awesome: { lucide: ["Sparkles"] },
  bolt: { lucide: ["Zap", "Bolt"] },
  calendar_month: { lucide: ["CalendarDays", "Calendar"] },
  call: { lucide: ["Phone", "PhoneCall"] },
  category: { lucide: ["Tag", "Shapes"] },
  chat: { lucide: ["MessageCircle", "MessagesSquare"] },
  check_circle: { iconoir: ["CheckCircle"], lucide: ["CheckCircle", "CircleCheck"] },
  chevron_right: { iconoir: ["NavArrowRight"], lucide: ["ChevronRight"] },
  cookie: { lucide: ["Cookie"] },
  database: { lucide: ["Database"] },
  delivery_dining: { lucide: ["Truck"] },
  description: { lucide: ["FileText", "ScrollText"] },
  directions_bike: { lucide: ["Bike"] },
  distance: { lucide: ["MapPin", "Navigation"] },
  download: { iconoir: ["Download"], lucide: ["Download"] },
  east: { lucide: ["ArrowRight"] },
  expand_more: { iconoir: ["NavArrowDown"], lucide: ["ChevronDown"] },
  format_quote: { lucide: ["Quote"] },
  forum: { lucide: ["MessagesSquare", "MessageCircle"] },
  group: { lucide: ["Users"] },
  groups: { lucide: ["Users"] },
  help: { lucide: ["CircleHelp"] },
  history: { lucide: ["History"] },
  info: { iconoir: ["InfoCircle"], lucide: ["Info"] },
  insights: { iconoir: ["GraphUp"], lucide: ["TrendingUp"] },
  inventory_2: { lucide: ["Package"] },
  language: { lucide: ["Languages", "Globe"] },
  local_mall: { iconoir: ["ShoppingBag"], lucide: ["ShoppingBag"] },
  local_shipping: { lucide: ["Truck"] },
  location_on: { lucide: ["MapPin"] },
  mail: { iconoir: ["Mail"], lucide: ["Mail"] },
  menu_book: { lucide: ["BookOpen"] },
  moped: { lucide: ["Bike"] },
  near_me: { lucide: ["Navigation"] },
  notifications_active: { iconoir: ["Bell"], lucide: ["BellRing"] },
  payments: { iconoir: ["CreditCard"], lucide: ["CreditCard"] },
  pedal_bike: { lucide: ["Bike"] },
  person: { iconoir: ["User"], lucide: ["User"] },
  policy: { lucide: ["ShieldCheck", "Shield"] },
  public: { lucide: ["Globe"] },
  request_quote: { lucide: ["Receipt", "CreditCard"] },
  restaurant: { iconoir: ["Shop"], lucide: ["Store"] },
  rocket_launch: { lucide: ["Rocket"] },
  schedule: { iconoir: ["Clock"], lucide: ["Clock3", "Clock"] },
  search: { iconoir: ["Search"], lucide: ["Search"] },
  settings: { iconoir: ["Settings"], lucide: ["Settings"] },
  share: { lucide: ["Share2"] },
  shield: { lucide: ["Shield"] },
  shopping_bag: { iconoir: ["ShoppingBag"], lucide: ["ShoppingBag"] },
  shopping_basket: { iconoir: ["Cart"], lucide: ["ShoppingBasket", "ShoppingCart"] },
  shopping_cart: { iconoir: ["Cart"], lucide: ["ShoppingCart"] },
  smartphone: { lucide: ["Smartphone"] },
  star: { iconoir: ["Star"], lucide: ["Star"] },
  storefront: { iconoir: ["Shop"], lucide: ["Store"] },
  support_agent: { lucide: ["Headset", "CircleHelp"] },
  task_alt: { lucide: ["CheckCircle", "CircleCheck"] },
  timer: { iconoir: ["Clock"], lucide: ["Timer", "Clock3"] },
  trending_up: { iconoir: ["GraphUp"], lucide: ["TrendingUp"] },
  tune: { lucide: ["SlidersHorizontal", "Settings2"] },
  two_wheeler: { lucide: ["Bike"] },
  update: { iconoir: ["Clock"], lucide: ["RefreshCw", "Clock3"] },
  verified: { lucide: ["BadgeCheck", "CheckCircle"] },
  verified_user: { lucide: ["ShieldCheck", "CheckCircle"] },
  west: { iconoir: ["NavArrowLeft"], lucide: ["ArrowLeft"] },
};

function resolveIconComponent(materialIconName: string) {
  const iconName = materialIconName.toLowerCase();
  const mapEntry = MATERIAL_ICON_MAP[iconName];

  if (mapEntry?.iconoir) {
    for (const candidate of mapEntry.iconoir) {
      const icon = ICONOIR_LIBRARY[candidate];
      if (icon) {
        return icon;
      }
    }
  }

  if (mapEntry?.lucide) {
    for (const candidate of mapEntry.lucide) {
      const icon = LUCIDE_LIBRARY[candidate];
      if (icon) {
        return icon;
      }
    }
  }

  return LUCIDE_LIBRARY.Circle;
}

export function StitchIconHydrator() {
  const pathname = usePathname();
  const rootsRef = useRef<Map<HTMLElement, Root>>(new Map());

  useEffect(() => {
    for (const root of rootsRef.current.values()) {
      root.unmount();
    }
    rootsRef.current.clear();

    const iconSlots = document.querySelectorAll<HTMLElement>("[data-stitch-icon]");
    iconSlots.forEach((iconSlot) => {
      const iconName = (iconSlot.dataset.stitchIcon ?? "circle").toLowerCase();
      const className = iconSlot.className
        .split(/\s+/)
        .filter((item) => item && item !== "stitch-icon-slot")
        .join(" ");

      const Icon = resolveIconComponent(iconName);
      const root = createRoot(iconSlot);

      root.render(
        <Icon
          aria-hidden="true"
          className={`${className} stitch-icon`.trim()}
          strokeWidth={1.85}
        />,
      );

      rootsRef.current.set(iconSlot, root);
    });

    return () => {
      for (const root of rootsRef.current.values()) {
        root.unmount();
      }
      rootsRef.current.clear();
    };
  }, [pathname]);

  useEffect(() => {
    const servicesSections = document.querySelectorAll<HTMLElement>("[data-services-scroll]");
    if (!servicesSections.length) {
      return;
    }

    const sectionCleanups: Array<() => void> = [];

    servicesSections.forEach((section) => {
      const panels = Array.from(
        section.querySelectorAll<HTMLElement>("[data-service-panel]"),
      );
      const shots = Array.from(
        section.querySelectorAll<HTMLElement>("[data-service-shot]"),
      );
      const steps = Array.from(
        section.querySelectorAll<HTMLElement>("[data-service-step]"),
      );
      const dots = Array.from(
        section.querySelectorAll<HTMLButtonElement>("[data-service-dot]"),
      );

      if (!panels.length || !steps.length) {
        return;
      }

      let activeIndex = -1;
      let raf = 0;
      const dotHandlers = new Map<HTMLButtonElement, EventListener>();
      const stage = section.querySelector<HTMLElement>(".services-center-stage");

      const clamp = (value: number, min: number, max: number) =>
        Math.min(max, Math.max(min, value));

      const setFocusProgress = () => {
        if (!stage) {
          section.style.setProperty("--services-focus", "0");
          return 0;
        }

        const sectionRect = section.getBoundingClientRect();
        const stageHeight = stage.offsetHeight;
        const scrollableRange = Math.max(1, sectionRect.height - stageHeight);
        const rawProgress = clamp((-sectionRect.top) / scrollableRange, 0, 1);
        const focusProgress = rawProgress;

        section.style.setProperty("--services-focus", focusProgress.toFixed(3));
        return focusProgress;
      };

      const setActive = (index: number) => {
        const nextIndex = Math.max(0, Math.min(index, panels.length - 1));
        if (nextIndex === activeIndex) {
          return;
        }

        activeIndex = nextIndex;

        panels.forEach((panel, panelIndex) => {
          panel.classList.toggle("is-active", panelIndex === nextIndex);
        });

        shots.forEach((shot, shotIndex) => {
          shot.classList.toggle("is-active", shotIndex === nextIndex);
        });

        dots.forEach((dot, dotIndex) => {
          dot.classList.toggle("is-active", dotIndex === nextIndex);
        });
      };

      const computeActiveFromScroll = () => {
        const focusProgress = setFocusProgress();
        const hasVisibleSteps = steps.some(
          (step) => step.offsetParent !== null && step.offsetHeight > 0,
        );

        if (!hasVisibleSteps) {
          if (activeIndex < 0) {
            setActive(0);
          }
          return;
        }

        const progressDrivenIndex = Math.min(
          panels.length - 1,
          Math.floor(focusProgress * panels.length),
        );
        setActive(progressDrivenIndex);
      };

      const queueCompute = () => {
        if (raf) {
          return;
        }

        raf = window.requestAnimationFrame(() => {
          raf = 0;
          computeActiveFromScroll();
        });
      };

      dots.forEach((dot, dotIndex) => {
        const handler: EventListener = () => {
          const step = steps[dotIndex];
          if (step && step.offsetParent !== null && step.offsetHeight > 0) {
            step.scrollIntoView({ behavior: "smooth", block: "center" });
            return;
          }

          setActive(dotIndex);
        };

        dot.addEventListener("click", handler);
        dotHandlers.set(dot, handler);
      });

      window.addEventListener("scroll", queueCompute, { passive: true });
      window.addEventListener("resize", queueCompute);
      computeActiveFromScroll();

      sectionCleanups.push(() => {
        if (raf) {
          window.cancelAnimationFrame(raf);
        }

        window.removeEventListener("scroll", queueCompute);
        window.removeEventListener("resize", queueCompute);
        section.style.removeProperty("--services-focus");

        dotHandlers.forEach((handler, dot) => {
          dot.removeEventListener("click", handler);
        });
      });
    });

    return () => {
      sectionCleanups.forEach((cleanup) => cleanup());
    };
  }, [pathname]);

  return null;
}
