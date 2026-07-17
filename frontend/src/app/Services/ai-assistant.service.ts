/*
 * Copyright (c) 2014-2026 Bjoern Kimminich & the OWASP Juice Shop contributors.
 * SPDX-License-Identifier: MIT
 */

import { Injectable, inject } from '@angular/core'
import { HttpClient } from '@angular/common/http'
import { Observable } from 'rxjs'
import { environment } from '../../environments/environment'

export interface AiChatMessage {
  role: 'user' | 'assistant'
  content: string
}

export interface AiChatResponse {
  reply: string
}

@Injectable({
  providedIn: 'root'
})
export class AiAssistantService {
  private readonly http = inject(HttpClient)
  private readonly baseUrl = environment.aiAssistantUrl

  chat (message: string, history: AiChatMessage[] = []): Observable<AiChatResponse> {
    return this.http.post<AiChatResponse>(`${this.baseUrl}/chat`, {
      message,
      history
    })
  }
}
