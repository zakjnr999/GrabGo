import { ScrollReveal } from "../components/scroll-reveal";

const services = [
  {
    title: "Food Delivery",
    detail: "Browse local restaurants, discover promos, and get meals delivered fast.",
    badge: "Live",
  },
  {
    title: "GrabMart",
    detail: "Shop groceries and home essentials from neighborhood stores in minutes.",
    badge: "Live",
  },
  {
    title: "Pharmacy",
    detail: "Order medications and health products with a guided prescription flow.",
    badge: "Live",
  },
  {
    title: "Ride-Hailing",
    detail: "Book point-to-point rides with the same reliable GrabGo experience.",
    badge: "Coming Soon",
  },
] as const;

type CoverageStatus = "Live" | "Limited" | "Soon";
type CoverageService = "Food" | "GrabMart" | "Pharmacy" | "Ride-Hailing";
type CoverageTone = "purple" | "orange" | "green" | "teal" | "blue" | "cream" | "pink" | "mint";

const coverageZones = [
  {
    city: "Accra Metro",
    eta: "18-35 mins",
    position: { x: "56%", y: "58%" },
    tone: "orange",
    areas: ["East Legon", "Osu", "Airport Residential", "Adabraka"],
    availability: [
      { service: "Food", status: "Live" },
      { service: "GrabMart", status: "Live" },
      { service: "Pharmacy", status: "Live" },
      { service: "Ride-Hailing", status: "Soon" },
    ],
  },
  {
    city: "Kumasi",
    eta: "22-40 mins",
    position: { x: "44%", y: "46%" },
    tone: "blue",
    areas: ["Adum", "Asokwa", "KNUST Environs", "Ahodwo"],
    availability: [
      { service: "Food", status: "Live" },
      { service: "GrabMart", status: "Live" },
      { service: "Pharmacy", status: "Limited" },
      { service: "Ride-Hailing", status: "Soon" },
    ],
  },
  {
    city: "Takoradi",
    eta: "25-45 mins",
    position: { x: "33%", y: "60%" },
    tone: "teal",
    areas: ["Market Circle", "Beach Road", "Anaji", "Kojokrom"],
    availability: [
      { service: "Food", status: "Live" },
      { service: "GrabMart", status: "Limited" },
      { service: "Pharmacy", status: "Live" },
      { service: "Ride-Hailing", status: "Soon" },
    ],
  },
  {
    city: "Tamale",
    eta: "20-38 mins",
    position: { x: "50%", y: "24%" },
    tone: "purple",
    areas: ["Central Business District", "Lamashegu", "Jisonayili", "Kalpohin"],
    availability: [
      { service: "Food", status: "Live" },
      { service: "GrabMart", status: "Limited" },
      { service: "Pharmacy", status: "Limited" },
      { service: "Ride-Hailing", status: "Soon" },
    ],
  },
] as const satisfies readonly {
  city: string;
  eta: string;
  position: { x: string; y: string };
  tone: CoverageTone;
  areas: readonly string[];
  availability: readonly { service: CoverageService; status: CoverageStatus }[];
}[];

const coverageStatusStyles: Record<CoverageStatus, string> = {
  Live: "bg-brand-orange/16 text-brand-orange",
  Limited: "bg-brand-teal/16 text-brand-teal",
  Soon: "bg-brand-ink/10 text-brand-ink/70",
};

const coverageServiceIcons: Record<CoverageService, string> = {
  Food: "FD",
  GrabMart: "GM",
  Pharmacy: "PH",
  "Ride-Hailing": "RH",
};

const coverageHotspots = [
  {
    label: "Tamale CBD",
    x: "51%",
    y: "18%",
    pinX: "54%",
    pinY: "28%",
    tone: "purple",
    service: "Food",
  },
  {
    label: "Lamashegu",
    x: "67%",
    y: "26%",
    pinX: "71%",
    pinY: "35%",
    tone: "mint",
    service: "GrabMart",
  },
  {
    label: "KNUST Environs",
    x: "34%",
    y: "34%",
    pinX: "29%",
    pinY: "45%",
    tone: "blue",
    service: "Food",
  },
  {
    label: "Adum Core",
    x: "53%",
    y: "38%",
    pinX: "56%",
    pinY: "47%",
    tone: "orange",
    service: "Pharmacy",
  },
  {
    label: "Market Circle",
    x: "23%",
    y: "52%",
    pinX: "16%",
    pinY: "63%",
    tone: "green",
    service: "Food",
  },
  {
    label: "Osu",
    x: "74%",
    y: "50%",
    pinX: "80%",
    pinY: "60%",
    tone: "teal",
    service: "GrabMart",
  },
  {
    label: "Airport Res.",
    x: "43%",
    y: "55%",
    pinX: "45%",
    pinY: "65%",
    tone: "cream",
    service: "Pharmacy",
  },
  {
    label: "East Legon",
    x: "27%",
    y: "74%",
    pinX: "30%",
    pinY: "83%",
    tone: "orange",
    service: "Food",
  },
  {
    label: "Adabraka",
    x: "63%",
    y: "73%",
    pinX: "69%",
    pinY: "81%",
    tone: "pink",
    service: "GrabMart",
  },
] as const satisfies readonly {
  label: string;
  x: string;
  y: string;
  pinX: string;
  pinY: string;
  tone: CoverageTone;
  service: CoverageService;
}[];

const coverageToneClass: Record<CoverageTone, string> = {
  purple: "coverage-tone-purple",
  orange: "coverage-tone-orange",
  green: "coverage-tone-green",
  teal: "coverage-tone-teal",
  blue: "coverage-tone-blue",
  cream: "coverage-tone-cream",
  pink: "coverage-tone-pink",
  mint: "coverage-tone-mint",
};

const coverageCardToneClass: Record<CoverageTone, string> = {
  purple: "coverage-card-tone-purple",
  orange: "coverage-card-tone-orange",
  green: "coverage-card-tone-green",
  teal: "coverage-card-tone-teal",
  blue: "coverage-card-tone-blue",
  cream: "coverage-card-tone-cream",
  pink: "coverage-card-tone-pink",
  mint: "coverage-card-tone-mint",
};

const features = [
  {
    title: "Live map tracking",
    detail: "Follow your rider in real time with continuous ETA updates.",
  },
  {
    title: "Chat and calls",
    detail: "Coordinate deliveries through text, voice notes, images, and calls.",
  },
  {
    title: "Smart savings",
    detail: "Use promo codes, referral rewards, and wallet credits at checkout.",
  },
  {
    title: "One account, many services",
    detail: "Move from food to groceries to pharmacy without switching apps.",
  },
  {
    title: "Reliable notifications",
    detail: "Receive updates for accepted, preparing, on-the-way, and delivered states.",
  },
  {
    title: "Reorder in one tap",
    detail: "Jump back into past orders with favorites and quick reorder actions.",
  },
] as const;

const audienceBlocks = [
  {
    title: "For Customers",
    points: [
      "Order food, groceries, and pharmacy products from one app",
      "Track every order from pickup to doorstep",
      "Use flexible payment options with promo support",
    ],
    cta: "Download App",
    href: "#download",
  },
  {
    title: "For Vendors",
    points: [
      "Receive and manage incoming orders in real time",
      "Run promos and story-style campaigns for visibility",
      "Monitor sales trends and inventory availability",
    ],
    cta: "Partner with GrabGo",
    href: "#download",
  },
  {
    title: "For Riders",
    points: [
      "Get proximity-based dispatch suggestions",
      "Track earnings and delivery performance",
      "Coordinate deliveries with in-app communication tools",
    ],
    cta: "Become a Rider",
    href: "#download",
  },
] as const;

const trustStats = [
  { value: "4", label: "Service categories" },
  { value: "Live", label: "GPS rider tracking" },
  { value: "24/7", label: "Order updates" },
  { value: "Multi-app", label: "Customer, Rider, Vendor ecosystem" },
] as const;

const testimonials = [
  {
    quote: "GrabGo is the only app I use now. Food at lunch, groceries at night, same simple flow.",
    author: "Ama T.",
    role: "Customer",
  },
  {
    quote: "Order visibility is clear and instant. We receive requests quickly and manage prep better.",
    author: "Kitchen Hub",
    role: "Vendor Partner",
  },
  {
    quote: "Dispatch feels fair and transparent. I can track my delivery performance every day.",
    author: "Kojo N.",
    role: "Rider",
  },
] as const;

const faqs = [
  {
    question: "What services are currently available on GrabGo?",
    answer:
      "GrabGo currently supports Food Delivery, GrabMart (groceries), and Pharmacy delivery. Ride-hailing is planned as a future expansion.",
  },
  {
    question: "Can I track my order after checkout?",
    answer:
      "Yes. GrabGo provides live rider location updates and ETA visibility from order confirmation to delivery completion.",
  },
  {
    question: "How do savings work on GrabGo?",
    answer:
      "You can apply promo codes at checkout and use referral rewards and wallet credits when eligible.",
  },
  {
    question: "Can vendors and riders join the platform?",
    answer:
      "Yes. GrabGo supports onboarding flows for partner vendors and riders with dedicated tools for order and performance management.",
  },
] as const;

export default function LandingPage() {
  return (
    <div className="relative overflow-x-hidden bg-brand-cream text-brand-ink">
      <div className="pointer-events-none absolute inset-0 -z-10 bg-[radial-gradient(circle_at_10%_20%,rgba(254,97,50,0.2),transparent_45%),radial-gradient(circle_at_90%_0%,rgba(31,122,140,0.15),transparent_35%),linear-gradient(180deg,#fff9f4_0%,#fffdf9_65%,#ffffff_100%)]" />
      <div className="pointer-events-none absolute -top-20 left-[-80px] -z-10 h-56 w-56 rounded-full bg-brand-orange/20 blur-3xl" />
      <div className="pointer-events-none absolute top-52 right-[-120px] -z-10 h-72 w-72 rounded-full bg-brand-teal/15 blur-3xl" />

      <header className="sticky top-0 z-30 border-b border-brand-ink/10 bg-brand-cream/85 backdrop-blur">
        <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
          <a className="font-display text-xl font-bold tracking-tight" href="#top">
            GrabGo
          </a>

          <nav className="hidden items-center gap-8 text-sm font-medium lg:flex">
            <a className="nav-link" href="#services">
              Services
            </a>
            <a className="nav-link" href="#coverage">
              Coverage
            </a>
            <a className="nav-link" href="#features">
              Features
            </a>
            <a className="nav-link" href="#how-it-works">
              How It Works
            </a>
            <a className="nav-link" href="#trust">
              Trust
            </a>
            <a className="nav-link" href="#faq">
              FAQ
            </a>
          </nav>

          <div className="hidden items-center gap-3 sm:flex">
            <a
              className="rounded-full border border-brand-ink/20 px-4 py-2 text-sm font-semibold transition hover:border-brand-orange hover:text-brand-orange"
              href="#for-everyone"
            >
              Partner
            </a>
            <a
              className="rounded-full bg-brand-orange px-5 py-2 text-sm font-semibold text-white transition hover:translate-y-[-1px] hover:bg-brand-orange-dark"
              href="#download"
            >
              Download App
            </a>
          </div>

          <details className="relative sm:hidden">
            <summary className="menu-summary rounded-full border border-brand-ink/20 px-4 py-2 text-sm font-semibold">
              Menu
            </summary>
            <div className="absolute right-0 mt-2 w-56 rounded-2xl border border-brand-ink/10 bg-white p-3">
              <a className="mobile-nav-link" href="#services">
                Services
              </a>
              <a className="mobile-nav-link" href="#coverage">
                Coverage
              </a>
              <a className="mobile-nav-link" href="#features">
                Features
              </a>
              <a className="mobile-nav-link" href="#how-it-works">
                How It Works
              </a>
              <a className="mobile-nav-link" href="#trust">
                Trust
              </a>
              <a className="mobile-nav-link" href="#faq">
                FAQ
              </a>
              <a className="mobile-nav-link" href="#download">
                Download App
              </a>
            </div>
          </details>
        </div>
      </header>

      <main id="top">
        <ScrollReveal delayMs={50}>
          <section className="mx-auto grid max-w-6xl items-center gap-14 px-6 pb-16 pt-14 md:grid-cols-[1.1fr_0.9fr] md:pt-20">
            <div className="space-y-8">
              <span className="inline-flex rounded-full border border-brand-orange/25 bg-brand-orange/10 px-3 py-1 text-xs font-semibold uppercase tracking-[0.16em] text-brand-orange">
                Everyday delivery, reimagined
              </span>
              <div className="space-y-5">
                <h1 className="max-w-2xl font-display text-4xl font-bold leading-[1.1] tracking-tight sm:text-5xl md:text-6xl">
                  Food, groceries, and pharmacy essentials in one fast app.
                </h1>
                <p className="max-w-xl text-base leading-7 text-brand-ink/75 sm:text-lg">
                  GrabGo helps you discover nearby stores, place orders in seconds,
                  and follow each delivery with live tracking and direct rider communication.
                </p>
              </div>
              <div className="flex flex-col gap-3 sm:flex-row">
                <a
                  className="rounded-full bg-brand-orange px-7 py-3 text-center text-sm font-semibold text-white transition hover:translate-y-[-1px] hover:bg-brand-orange-dark"
                  href="#download"
                >
                  Start Ordering
                </a>
                <a
                  className="rounded-full border border-brand-ink/20 bg-white/70 px-7 py-3 text-center text-sm font-semibold backdrop-blur transition hover:border-brand-teal hover:text-brand-teal"
                  href="#how-it-works"
                >
                  See How It Works
                </a>
              </div>
              <div className="grid max-w-md grid-cols-2 gap-3 sm:grid-cols-4">
                {trustStats.map((stat) => (
                  <div key={stat.label} className="rounded-xl border border-brand-ink/10 bg-white/65 p-3">
                    <p className="font-display text-xl font-bold">{stat.value}</p>
                    <p className="text-[11px] uppercase tracking-wide text-brand-ink/60">{stat.label}</p>
                  </div>
                ))}
              </div>
            </div>

            <div className="animate-float-up relative">
              <div className="relative overflow-hidden rounded-[2rem] border border-brand-ink/10 bg-white p-6">
                <div className="mb-5 flex items-center justify-between">
                  <p className="font-display text-lg font-semibold">Live Delivery Board</p>
                  <span className="rounded-full bg-brand-orange/15 px-3 py-1 text-xs font-semibold text-brand-orange">
                    Real-Time
                  </span>
                </div>
                <div className="space-y-4">
                  <div className="rounded-2xl border border-brand-ink/10 bg-brand-cream/50 p-4">
                    <div className="mb-2 flex items-center justify-between text-sm">
                      <span className="font-semibold">Order #GG-2012</span>
                      <span className="text-brand-teal">7 mins</span>
                    </div>
                    <p className="text-sm text-brand-ink/70">Rider is approaching pickup point.</p>
                  </div>
                  <div className="rounded-2xl border border-brand-ink/10 bg-brand-cream/50 p-4">
                    <div className="mb-2 flex items-center justify-between text-sm">
                      <span className="font-semibold">Order #GG-2015</span>
                      <span className="text-brand-teal">14 mins</span>
                    </div>
                    <p className="text-sm text-brand-ink/70">Pharmacy order is out for delivery.</p>
                  </div>
                  <div className="rounded-2xl border border-brand-ink/10 bg-brand-cream/50 p-4">
                    <div className="mb-2 flex items-center justify-between text-sm">
                      <span className="font-semibold">Order #GG-2017</span>
                      <span className="text-brand-teal">4 mins</span>
                    </div>
                    <p className="text-sm text-brand-ink/70">Groceries arriving at your address.</p>
                  </div>
                </div>
              </div>
            </div>
          </section>
          <div className="mx-auto mt-6 max-w-6xl px-6 pb-10 md:pb-14">
            <div className="overflow-hidden rounded-t-[1.25rem] border border-brand-ink/15 border-b-0">
              <div className="umbrella-divider">
                <p className="umbrella-divider-text">
                  One app. Three live services. Zero hassle.
                </p>
              </div>
            </div>
          </div>
        </ScrollReveal>

        <ScrollReveal delayMs={80}>
          <section id="services" className="mx-auto max-w-6xl px-6 py-16">
            <div className="mb-8 flex flex-wrap items-end justify-between gap-5">
              <div>
                <p className="section-label">Services</p>
                <h2 className="section-title">Everything you need, one platform.</h2>
              </div>
              <p className="max-w-xl text-sm leading-6 text-brand-ink/70">
                GrabGo combines daily essentials, prepared meals, and medicine
                delivery into one consistent ordering experience.
              </p>
            </div>
            <div className="grid gap-4 sm:grid-cols-2">
              {services.map((service) => (
                <article
                  key={service.title}
                  className="rounded-3xl border border-brand-ink/10 bg-white p-6 transition hover:-translate-y-1"
                >
                  <div className="mb-4 flex items-center justify-between">
                    <h3 className="font-display text-2xl font-semibold tracking-tight">{service.title}</h3>
                    <span
                      className={`rounded-full px-3 py-1 text-xs font-semibold ${
                        service.badge === "Coming Soon"
                          ? "bg-brand-teal/15 text-brand-teal"
                          : "bg-brand-orange/15 text-brand-orange"
                      }`}
                    >
                      {service.badge}
                    </span>
                  </div>
                  <p className="text-sm leading-6 text-brand-ink/70">{service.detail}</p>
                </article>
              ))}
            </div>
          </section>
        </ScrollReveal>

        <ScrollReveal delayMs={85}>
          <section id="coverage" className="mx-auto max-w-6xl px-6 py-16">
            <div className="mb-8 flex flex-wrap items-end justify-between gap-5">
              <div>
                <p className="section-label">Coverage</p>
                <h2 className="section-title">Coverage map and service availability.</h2>
              </div>
              <p className="max-w-xl text-sm leading-6 text-brand-ink/70">
                Availability varies by neighborhood and service type. Enter your delivery
                address in-app to confirm the latest live coverage.
              </p>
            </div>

            <div className="coverage-shell overflow-hidden rounded-[2rem] bg-white">
              <div className="coverage-layout grid lg:grid-cols-[1.62fr_1fr]">
                <div className="coverage-map-wrap">
                  <div className="coverage-map">
                    <div className="coverage-map-toolbar">
                      <span className="coverage-map-chip coverage-map-chip-primary">GrabGo Coverage Radar</span>
                      <span className="coverage-map-chip">Updated Today</span>
                    </div>

                    <svg className="coverage-water-patches" viewBox="0 0 1000 640" aria-hidden="true">
                      <path d="M0 0h140l-90 160H0z" />
                      <path d="M1000 0v110l-170-72L770 0z" />
                      <path d="M0 640v-105l86-40 52 145z" />
                      <path d="M1000 640h-140l95-165 45 18z" />
                    </svg>

                    <svg className="coverage-district-blocks" viewBox="0 0 1000 640" aria-hidden="true">
                      <path d="M104 76h188l-68 108H88z" />
                      <path d="M294 98h214v164H266z" />
                      <path d="M542 88h248l58 156H560z" />
                      <path d="M120 270h194v162H118z" />
                      <path d="M350 292h212l-58 176H340z" />
                      <path d="M604 286h244l44 186H604z" />
                      <path d="M98 466h258l-66 126H82z" />
                      <path d="M390 486h244v122H366z" />
                      <path d="M674 500h224l-56 118H640z" />
                    </svg>

                    <svg className="coverage-green-zones" viewBox="0 0 1000 640" aria-hidden="true">
                      <path d="M178 210c28-35 82-37 109-4 23 30 13 74-22 95-39 23-88 9-106-31-12-23-6-48 19-60z" />
                      <path d="M704 190c22-29 70-31 95-6 22 24 24 64 4 91-26 36-81 42-112 9-23-24-19-62 13-94z" />
                      <path d="M474 402c24-28 66-30 91-9 24 20 31 55 14 84-21 37-72 52-106 29-35-22-35-73 1-104z" />
                    </svg>

                    <svg className="coverage-river" viewBox="0 0 1000 640" aria-hidden="true">
                      <path d="M80 166c74 18 160 3 233 28 71 24 120 83 186 117 72 36 168 44 245 94 77 50 143 122 224 140" />
                      <path d="M80 166c74 18 160 3 233 28 71 24 120 83 186 117 72 36 168 44 245 94 77 50 143 122 224 140" />
                    </svg>

                    <svg className="coverage-roads-secondary" viewBox="0 0 1000 640" aria-hidden="true">
                      <polyline points="350,0 326,206 296,395 330,640" />
                      <polyline points="738,0 755,186 774,404 752,640" />
                      <polyline points="0,308 214,300 444,300 678,306 1000,302" />
                      <polyline points="0,482 190,450 404,390 612,314 860,188 1000,128" />
                    </svg>

                    <svg className="coverage-roads-major" viewBox="0 0 1000 640" aria-hidden="true">
                      <polyline points="86,0 0,134 86,220 100,418 0,542" />
                      <polyline points="640,0 470,124 446,304 612,432 575,640" />
                      <polyline points="264,0 150,182 462,182 1000,162" />
                      <polyline points="1000,330 824,302 654,392 440,520 210,640" />
                      <polyline points="0,560 282,560 522,432 842,420 860,640" />
                    </svg>

                    <svg className="coverage-roads-minor" viewBox="0 0 1000 640" aria-hidden="true">
                      <polyline points="120,90 200,70 300,105 430,95" />
                      <polyline points="180,230 260,250 340,220 420,240" />
                      <polyline points="520,130 590,120 670,145 730,130" />
                      <polyline points="520,230 610,250 700,220 770,235" />
                      <polyline points="170,355 270,360 360,330 430,350" />
                      <polyline points="530,350 620,340 720,365 780,350" />
                      <polyline points="140,500 240,470 350,500 430,470" />
                      <polyline points="520,495 620,475 720,500 790,470" />
                    </svg>

                    {coverageHotspots.map((spot) => (
                      <div
                        key={`hotspot-label-${spot.label}`}
                        className={`coverage-location-tag ${coverageToneClass[spot.tone]}`}
                        style={{ left: spot.x, top: spot.y }}
                      >
                        <span className="coverage-location-tag-icon">{coverageServiceIcons[spot.service]}</span>
                        <span className="coverage-location-tag-text">{spot.label}</span>
                      </div>
                    ))}

                    {coverageHotspots.map((spot) => (
                      <span
                        key={`hotspot-pin-${spot.label}`}
                        className={`coverage-marker ${coverageToneClass[spot.tone]}`}
                        style={{ left: spot.pinX, top: spot.pinY }}
                        aria-hidden="true"
                      />
                    ))}

                    <p className="coverage-map-caption">
                      <span className="coverage-map-caption-dot" />
                      Tap a zone tag to preview available services and stores nearby.
                    </p>
                  </div>
                </div>

                <aside className="coverage-list-panel">
                  <div className="coverage-list-header">
                    <h3>Coverage Pulse</h3>
                    <p>Live availability by city and neighborhood clusters.</p>
                  </div>
                  <div className="coverage-list-legend">
                    {(["Live", "Limited", "Soon"] as const).map((status) => (
                      <span key={`legend-${status}`} className={`coverage-legend-pill ${coverageStatusStyles[status]}`}>
                        {status}
                      </span>
                    ))}
                  </div>
                  <div className="coverage-list-scroll">
                    {coverageZones.map((zone) => (
                      <article
                        key={`card-${zone.city}`}
                        className={`coverage-list-item ${coverageCardToneClass[zone.tone]}`}
                      >
                        <div className="coverage-list-top">
                          <div>
                            <p className="coverage-list-title">{zone.city}</p>
                            <p className="coverage-list-subtitle">{zone.eta} average delivery window</p>
                          </div>
                          <span className="coverage-list-eta">{zone.eta}</span>
                        </div>

                        <div className="coverage-area-chip-row">
                          {zone.areas.slice(0, 3).map((area) => (
                            <span key={`${zone.city}-area-${area}`} className="coverage-area-chip">
                              {area}
                            </span>
                          ))}
                          {zone.areas.length > 3 ? (
                            <span className="coverage-area-chip coverage-area-chip-muted">
                              +{zone.areas.length - 3} more
                            </span>
                          ) : null}
                        </div>

                        <div className="coverage-list-icons">
                          {zone.availability.map((item) => (
                            <span
                              key={`${zone.city}-${item.service}-icon`}
                              className={`coverage-service-icon ${coverageStatusStyles[item.status]}`}
                              title={`${item.service}: ${item.status}`}
                            >
                              {coverageServiceIcons[item.service]}
                            </span>
                          ))}
                        </div>

                        <div className="coverage-service-grid">
                          {zone.availability.map((item) => (
                            <div key={`${zone.city}-${item.service}`} className="coverage-service-row">
                              <span className="coverage-service-name">{item.service}</span>
                              <span className={`coverage-service-pill ${coverageStatusStyles[item.status]}`}>
                                <span className="coverage-service-pill-dot" aria-hidden="true" />
                                {item.status}
                              </span>
                            </div>
                          ))}
                        </div>
                      </article>
                    ))}
                  </div>
                </aside>
              </div>
            </div>
          </section>
        </ScrollReveal>

        <ScrollReveal delayMs={90}>
          <section id="features" className="mx-auto max-w-6xl px-6 py-16">
            <div className="rounded-[2rem] border border-brand-ink/10 bg-white p-8 md:p-10">
              <p className="section-label">Core Features</p>
              <h2 className="section-title mb-8">Why users stay with GrabGo.</h2>
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {features.map((feature) => (
                  <article
                    key={feature.title}
                    className="rounded-2xl border border-brand-ink/10 bg-brand-cream/50 p-4"
                  >
                    <h3 className="mb-2 font-display text-xl font-semibold tracking-tight">{feature.title}</h3>
                    <p className="text-sm leading-6 text-brand-ink/75">{feature.detail}</p>
                  </article>
                ))}
              </div>
            </div>
          </section>
        </ScrollReveal>

        <ScrollReveal delayMs={100}>
          <section id="how-it-works" className="mx-auto max-w-6xl px-6 py-16">
            <p className="section-label">How It Works</p>
            <h2 className="section-title mb-8">From order to doorstep in four steps.</h2>
            <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
              {[
                "Choose a service",
                "Add items and checkout",
                "Track your rider live",
                "Receive and rate delivery",
              ].map((step, index) => (
                <div
                  key={step}
                  className="rounded-2xl border border-brand-ink/10 bg-white p-5"
                >
                  <p className="mb-3 font-display text-3xl font-bold text-brand-orange/80">0{index + 1}</p>
                  <p className="text-sm font-medium leading-6 text-brand-ink/80">{step}</p>
                </div>
              ))}
            </div>
          </section>
        </ScrollReveal>

        <ScrollReveal delayMs={110}>
          <section id="trust" className="mx-auto max-w-6xl px-6 py-16">
            <div className="mb-8">
              <p className="section-label">Trust & Reliability</p>
              <h2 className="section-title">Built for consistency, not just convenience.</h2>
            </div>
            <div className="grid gap-5 lg:grid-cols-[0.9fr_1.1fr]">
              <div className="space-y-4 rounded-3xl border border-brand-ink/10 bg-white p-6">
                {trustStats.map((stat) => (
                  <div key={stat.label} className="rounded-2xl border border-brand-ink/10 bg-brand-cream/40 p-4">
                    <p className="font-display text-2xl font-bold">{stat.value}</p>
                    <p className="text-sm text-brand-ink/70">{stat.label}</p>
                  </div>
                ))}
              </div>
              <div className="grid gap-4 md:grid-cols-2">
                {testimonials.map((testimonial) => (
                  <article
                    key={testimonial.author}
                    className="rounded-3xl border border-brand-ink/10 bg-white p-6 md:odd:translate-y-4"
                  >
                    <p className="mb-5 text-sm leading-7 text-brand-ink/80">“{testimonial.quote}”</p>
                    <p className="font-display text-lg font-semibold">{testimonial.author}</p>
                    <p className="text-xs uppercase tracking-wide text-brand-ink/55">{testimonial.role}</p>
                  </article>
                ))}
              </div>
            </div>
          </section>
        </ScrollReveal>

        <ScrollReveal delayMs={120}>
          <section id="for-everyone" className="mx-auto max-w-6xl px-6 py-16">
            <div className="mb-8">
              <p className="section-label">For Everyone</p>
              <h2 className="section-title">Built for customers, vendors, and riders.</h2>
            </div>
            <div className="grid gap-5 lg:grid-cols-3">
              {audienceBlocks.map((block) => (
                <article
                  key={block.title}
                  className="rounded-3xl border border-brand-ink/10 bg-white p-6"
                >
                  <h3 className="mb-4 font-display text-2xl font-semibold tracking-tight">{block.title}</h3>
                  <ul className="space-y-2 text-sm leading-6 text-brand-ink/75">
                    {block.points.map((point) => (
                      <li key={point}>• {point}</li>
                    ))}
                  </ul>
                  <a
                    className="mt-6 inline-flex rounded-full border border-brand-ink/20 px-4 py-2 text-sm font-semibold transition hover:border-brand-orange hover:text-brand-orange"
                    href={block.href}
                  >
                    {block.cta}
                  </a>
                </article>
              ))}
            </div>
          </section>
        </ScrollReveal>

        <ScrollReveal delayMs={130}>
          <section id="faq" className="mx-auto max-w-6xl px-6 py-16">
            <div className="mb-8">
              <p className="section-label">FAQ</p>
              <h2 className="section-title">Common questions from new users.</h2>
            </div>
            <div className="space-y-3">
              {faqs.map((faq) => (
                <details key={faq.question} className="rounded-2xl border border-brand-ink/10 bg-white p-5">
                  <summary className="menu-summary cursor-pointer list-none font-display text-lg font-semibold tracking-tight">
                    {faq.question}
                  </summary>
                  <p className="mt-3 text-sm leading-7 text-brand-ink/75">{faq.answer}</p>
                </details>
              ))}
            </div>
          </section>
        </ScrollReveal>

        <ScrollReveal delayMs={140}>
          <section id="download" className="mx-auto max-w-6xl px-6 py-16">
            <div className="rounded-[2.2rem] bg-brand-ink px-8 py-12 text-brand-cream md:px-12">
              <p className="mb-2 text-xs font-semibold uppercase tracking-[0.16em] text-brand-orange/90">
                Start with GrabGo
              </p>
              <h2 className="max-w-3xl font-display text-3xl font-bold leading-tight tracking-tight md:text-4xl">
                Your city, delivered better. Download GrabGo and place your first order today.
              </h2>
              <div className="mt-7 flex flex-col gap-3 sm:flex-row">
                <a
                  className="rounded-full bg-brand-orange px-7 py-3 text-center text-sm font-semibold text-white transition hover:bg-brand-orange-dark"
                  href="#"
                >
                  Download for iOS
                </a>
                <a
                  className="rounded-full border border-brand-cream/30 px-7 py-3 text-center text-sm font-semibold transition hover:border-brand-cream hover:bg-white/10"
                  href="#"
                >
                  Download for Android
                </a>
              </div>
            </div>
          </section>
        </ScrollReveal>
      </main>

      <footer className="border-t border-brand-ink/10 bg-white/70">
        <div className="mx-auto flex max-w-6xl flex-col gap-4 px-6 py-8 text-sm text-brand-ink/70 sm:flex-row sm:items-center sm:justify-between">
          <p>© {new Date().getFullYear()} GrabGo. All rights reserved.</p>
          <div className="flex flex-wrap gap-5">
            <a className="nav-link" href="#">
              Privacy
            </a>
            <a className="nav-link" href="#">
              Terms
            </a>
            <a className="nav-link" href="#">
              Support
            </a>
          </div>
        </div>
      </footer>
    </div>
  );
}
