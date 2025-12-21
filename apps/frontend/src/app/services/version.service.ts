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
  private frontendVersion: string;

  constructor(private http: HttpClient) {
    // Get frontend version from package.json at build time
    // This will be replaced during build
    this.frontendVersion = '{{VERSION}}';
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

