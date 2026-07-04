export function Logo({ size = 28 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 40 40" fill="none" xmlns="http://www.w3.org/2000/svg">
      <rect x="2" y="2" width="36" height="36" rx="10" fill="url(#lucid-grad)" />
      <path
        d="M20 8 L28 20 L20 32 L12 20 Z"
        fill="none"
        stroke="white"
        strokeWidth="1.6"
        strokeOpacity="0.9"
      />
      <circle cx="20" cy="20" r="3.2" fill="white" />
      <defs>
        <linearGradient id="lucid-grad" x1="0" y1="0" x2="40" y2="40" gradientUnits="userSpaceOnUse">
          <stop stopColor="#8B5CF6" />
          <stop offset="1" stopColor="#5B21B6" />
        </linearGradient>
      </defs>
    </svg>
  );
}
