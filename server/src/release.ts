import { existsSync, mkdirSync, readFileSync, renameSync, statSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';

export interface ReleaseInfo {
  version: string;
  build: string;
  datum: string;
  groesse: number;
  hinweise: string;
}

export const BUNDLE_ID = 'de.nglab.sentinel';

/** Ablage der aktuellen App-Version und Erzeugung der SideStore-Quelle. */
export class ReleaseStore {
  private readonly dir: string;

  constructor(
    dataDir: string,
    private readonly publicUrl: string,
  ) {
    this.dir = join(dataDir, 'releases');
    mkdirSync(this.dir, { recursive: true });
  }

  get ipaPath(): string {
    return join(this.dir, 'Sentinel.ipa');
  }

  current(): ReleaseInfo | null {
    const file = join(this.dir, 'release.json');
    if (!existsSync(file) || !existsSync(this.ipaPath)) return null;
    return JSON.parse(readFileSync(file, 'utf8')) as ReleaseInfo;
  }

  /** Übernimmt eine fertig hochgeladene Datei als aktuelle Version. */
  publish(tempFile: string, version: string, build: string, hinweise: string): ReleaseInfo {
    renameSync(tempFile, this.ipaPath);
    const info: ReleaseInfo = { version, build, datum: new Date().toISOString(), groesse: statSync(this.ipaPath).size, hinweise };
    writeFileSync(join(this.dir, 'release.json'), JSON.stringify(info, null, 2));
    return info;
  }

  tempPath(): string {
    return join(this.dir, `upload-${process.pid}-${Date.now()}.tmp`);
  }

  /** Quelle im AltStore/SideStore-Format. */
  source(): Record<string, unknown> {
    const release = this.current();
    const iconURL = `${this.publicUrl}/sidestore/icon.png`;
    const description =
      'SENTINEL unterstützt Zivilfahnder bei Observation und Fahndung: gemeinsame Lagekarte, A-Position, Zielpersonen, Bestreifung und Weg-Zeit-Berechnung.';
    const versions = release
      ? [
          {
            version: release.version,
            buildVersion: release.build,
            date: release.datum,
            localizedDescription: release.hinweise || 'Aktuelle Version.',
            downloadURL: `${this.publicUrl}/sidestore/Sentinel-${release.version}-${release.build}.ipa`,
            size: release.groesse,
            minOSVersion: '26.0',
          },
        ]
      : [];
    return {
      name: 'SENTINEL',
      identifier: `${BUNDLE_ID}.quelle`,
      subtitle: 'Lagekarte für Observation und Fahndung',
      description,
      iconURL,
      website: this.publicUrl,
      tintColor: '#0A84FF',
      apps: [
        {
          name: 'SENTINEL',
          bundleIdentifier: BUNDLE_ID,
          developerName: 'NG-Lab',
          subtitle: 'Lagekarte für Observation und Fahndung',
          localizedDescription: description,
          iconURL,
          tintColor: '#0A84FF',
          category: 'utilities',
          screenshots: [],
          versions,
          // Felder für ältere SideStore-Versionen:
          ...(versions[0]
            ? {
                version: versions[0].version,
                versionDate: versions[0].date,
                versionDescription: versions[0].localizedDescription,
                downloadURL: versions[0].downloadURL,
                size: versions[0].size,
              }
            : {}),
          appPermissions: {
            entitlements: [],
            privacy: {
              NSLocationWhenInUseUsageDescription: 'Der eigene Standort wird mit dem Einsatzteam geteilt.',
              NSLocationAlwaysAndWhenInUseUsageDescription: 'Der Standort wird auch im Hintergrund mit dem Einsatzteam geteilt.',
              NSCameraUsageDescription: 'Fotos für Profile, Fahrzeuge und Zielpersonen.',
              NSFaceIDUsageDescription: 'Schutz der App vor unbefugtem Zugriff.',
            },
          },
        },
      ],
      news: [],
    };
  }
}
