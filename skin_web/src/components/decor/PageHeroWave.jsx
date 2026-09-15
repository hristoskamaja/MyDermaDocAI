// Shared decorative backdrop for the small full-bleed "page hero" bands used
// on the patient-facing Scan / History / Find a Dermatologist / Profile pages.
// Same idea as Home.jsx's HeroWaveBackground (curved bottom edge + faint
// skin-spot dots), just shorter, so all patient pages share one visual motif.
export default function PageHeroWave() {
    return (
        <svg
            className="page-hero-wave"
            viewBox="0 0 1440 210"
            preserveAspectRatio="none"
            role="presentation"
            aria-hidden="true"
        >
            <path
                d="M0,0 L1440,0 L1440,120 C1140,190 700,210 360,160 C170,130 60,110 0,130 Z"
                fill="var(--primary)"
            />
            <circle cx="90" cy="45" r="4" fill="#fff" opacity="0.3" />
            <circle cx="150" cy="85" r="3" fill="#fff" opacity="0.2" />
            <circle cx="60" cy="115" r="5" fill="#fff" opacity="0.16" />
            <circle cx="1300" cy="40" r="4" fill="#fff" opacity="0.3" />
            <circle cx="1200" cy="95" r="3" fill="#fff" opacity="0.22" />
            <circle cx="1360" cy="130" r="6" fill="none" stroke="#fff" strokeWidth="1.5" opacity="0.25" />
            <circle cx="1360" cy="130" r="2" fill="#fff" opacity="0.28" />
        </svg>
    );
}
