"use client";

import { useEffect, useState } from "react";

import { siteConfig } from "@/site.config";

/** Stable alias served by Nginx from the host-mounted downloads directory. */
export const WINDOWS_INSTALLER_PATH = "/downloads/Oryon-windows-x64-setup.exe";

const MANIFEST_PATH = "/downloads/latest.json";

export type WindowsRelease = {
  url: string;
  version: string;
  sizeMb: number;
  sha256: string;
};

type Manifest = {
  version?: string;
  sizeMb?: number;
  sha256?: string;
  url?: string;
};

type WindowsReleaseState = {
  /** True until the first probe finishes. The server-rendered fallback is "soon". */
  loading: boolean;
  release: WindowsRelease | null;
};

let probe: Promise<WindowsRelease | null> | null = null;

/**
 * A configured `DOWNLOADS.windows.url` wins immediately. Leave it empty to let
 * the page discover whatever has been published under `/downloads/`.
 */
function configuredRelease(): WindowsRelease | null {
  const config = siteConfig.downloads.windows;
  if (!config.url.trim()) return null;

  return {
    url: config.url,
    version: config.version,
    sizeMb: config.sizeMb,
    sha256: config.sha256,
  };
}

async function readManifest(): Promise<Manifest | null> {
  try {
    const response = await fetch(MANIFEST_PATH, { cache: "no-store" });
    if (!response.ok) return null;

    const data = (await response.json()) as Manifest;
    return data?.version ? data : null;
  } catch {
    return null;
  }
}

async function installerExists(): Promise<{ sizeMb: number } | null> {
  try {
    const response = await fetch(WINDOWS_INSTALLER_PATH, {
      method: "HEAD",
      cache: "no-store",
    });
    if (!response.ok) return null;

    const length = Number(response.headers.get("content-length") ?? 0);
    return {
      sizeMb: length > 0 ? Math.round((length / 1_048_576) * 10) / 10 : 0,
    };
  } catch {
    return null;
  }
}

async function detectRelease(): Promise<WindowsRelease | null> {
  // `latest.json` is written by scripts/publish-release.sh and carries the
  // version, size and checksum. Prefer it when present.
  const manifest = await readManifest();
  if (manifest) {
    return {
      url: manifest.url?.trim() || WINDOWS_INSTALLER_PATH,
      version: manifest.version ?? "",
      sizeMb:
        typeof manifest.sizeMb === "number" && Number.isFinite(manifest.sizeMb)
          ? manifest.sizeMb
          : 0,
      sha256: manifest.sha256 ?? "",
    };
  }

  // Uploading the stable filename alone is enough to flip the page. This is
  // the manual path: copy the .exe into /srv/oryon/downloads and reload.
  const head = await installerExists();
  if (!head) return null;

  return {
    url: WINDOWS_INSTALLER_PATH,
    version: "Latest",
    sizeMb: head.sizeMb,
    sha256: "",
  };
}

export function useWindowsRelease(): WindowsReleaseState {
  const initial = configuredRelease();
  const [state, setState] = useState<WindowsReleaseState>({
    loading: !initial,
    release: initial,
  });

  useEffect(() => {
    let active = true;

    let request = probe;
    if (!request) {
      request = detectRelease().then((release) => {
        // Do not cache a miss: the installer may be uploaded while the site is
        // open, and the next mount should try again.
        if (!release) probe = null;
        return release;
      });
      probe = request;
    }

    request.then((release) => {
      if (!active) return;

      setState((current) => ({
        loading: false,
        release: release ?? current.release,
      }));
    }).catch(() => {
      if (!active) return;
      setState((current) => ({ loading: false, release: current.release }));
    });

    return () => {
      active = false;
    };
  }, []);

  return state;
}
