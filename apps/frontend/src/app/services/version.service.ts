import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { environment } from '../../environments/environment';

export interface VersionInfo {
  service: string;
  version: string;
  timestamp: string;
  serviceLocation?: string;
  connectionMethod?: string;
}

@Injectable({
  providedIn: 'root'
})
export class VersionService {
  private frontendVersion: string = '{{VERSION}}';

  constructor(private http: HttpClient) {
    // Version will be injected during build by inject-version.js
    // If still showing {{VERSION}}, fetch from version.json asset
    if (this.frontendVersion === '{{VERSION}}') {
      this.loadVersionFromAsset();
    }
  }

  private async loadVersionFromAsset() {
    try {
      const response = await fetch('/assets/version.json');
      const data = await response.json();
      this.frontendVersion = data.version;
    } catch (error) {
      console.warn('Could not load version from asset, using default');
      this.frontendVersion = 'unknown';
    }
  }

  getFrontendVersion(): string {
    return this.frontendVersion;
  }

  getBackendVersion(): Observable<VersionInfo> {
    return this.http.get<VersionInfo>(`${environment.backendUrl}/api/version`);
  }

  getCacheBustingQuery(): string {
    // Use version + timestamp for cache busting
    const timestamp = new Date().getTime();
    return `?v=${this.frontendVersion}&t=${timestamp}`;
  }
}

