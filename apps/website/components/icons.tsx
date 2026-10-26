import type { SVGProps } from "react";

type IconProps = SVGProps<SVGSVGElement>;

function Icon({ children, ...props }: IconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={1.8}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      {children}
    </svg>
  );
}

export function ChevronRightIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="m9 5 7 7-7 7" />
    </Icon>
  );
}

export function ArrowDownIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M12 4v15" />
      <path d="m6.5 13.5 5.5 5.5 5.5-5.5" />
    </Icon>
  );
}

export function DownloadIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M12 3.5v11" />
      <path d="m7.5 10 4.5 4.5 4.5-4.5" />
      <path d="M4.5 19.5h15" />
    </Icon>
  );
}

export function CheckIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="m4.5 12.5 4.5 4.5 10-10" />
    </Icon>
  );
}

export function MenuIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="M4 7h16" />
      <path d="M4 12h16" />
      <path d="M4 17h16" />
    </Icon>
  );
}

export function CloseIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <path d="m6 6 12 12" />
      <path d="M18 6 6 18" />
    </Icon>
  );
}

export function CopyIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <rect x="9" y="9" width="11" height="11" rx="2.5" />
      <path d="M15 5.5A2.5 2.5 0 0 0 12.5 3h-7A2.5 2.5 0 0 0 3 5.5v7A2.5 2.5 0 0 0 5.5 15" />
    </Icon>
  );
}

export function ClockIcon(props: IconProps) {
  return (
    <Icon {...props}>
      <circle cx="12" cy="12" r="8.5" />
      <path d="M12 7.5V12l3 2" />
    </Icon>
  );
}

export function WhatsAppIcon(props: IconProps) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <path d="M12.04 2.25a9.68 9.68 0 0 0-8.3 14.66L2.25 21.75l4.97-1.45a9.68 9.68 0 1 0 4.82-18.05Zm0 1.75a7.93 7.93 0 0 1 0 15.86 7.9 7.9 0 0 1-4.02-1.1l-.3-.18-2.95.86.88-2.87-.2-.31a7.93 7.93 0 0 1 6.59-12.26Zm-3.1 4.05c-.18 0-.46.07-.7.33-.24.26-.92.9-.92 2.19 0 1.3.94 2.55 1.07 2.72.13.18 1.83 2.93 4.53 3.98 2.24.88 2.7.7 3.19.66.49-.04 1.57-.64 1.79-1.26.22-.62.22-1.15.15-1.26-.07-.11-.26-.18-.55-.33-.29-.15-1.72-.85-1.99-.95-.27-.1-.46-.15-.66.15-.2.29-.75.94-.92 1.13-.17.2-.34.22-.63.07-.29-.15-1.22-.45-2.32-1.43-.86-.76-1.43-1.7-1.6-1.99-.17-.29-.02-.45.13-.6.13-.13.29-.34.44-.51.15-.17.2-.29.29-.48.1-.2.05-.37-.02-.51-.07-.15-.66-1.57-.9-2.15-.24-.56-.48-.49-.66-.5l-.56-.01Z" />
    </svg>
  );
}

export function WindowMinimiseIcon(props: IconProps) {
  return (
    <svg
      viewBox="0 0 10 10"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <path d="M2 5.5h6" stroke="currentColor" strokeWidth="1.1" />
    </svg>
  );
}

export function WindowMaximiseIcon(props: IconProps) {
  return (
    <svg
      viewBox="0 0 10 10"
      fill="none"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <rect
        x="2.1"
        y="2.1"
        width="5.8"
        height="5.8"
        rx="0.4"
        stroke="currentColor"
        strokeWidth="1.1"
      />
    </svg>
  );
}

export function WindowCloseIcon(props: IconProps) {
  return (
    <svg
      viewBox="0 0 10 10"
      aria-hidden="true"
      focusable="false"
      {...props}
    >
      <path
        d="m2.4 2.4 5.2 5.2M7.6 2.4 2.4 7.6"
        stroke="currentColor"
        strokeWidth="1.1"
        strokeLinecap="round"
      />
    </svg>
  );
}
