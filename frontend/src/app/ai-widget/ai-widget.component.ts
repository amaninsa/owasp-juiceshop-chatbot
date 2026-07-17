/*
 * Copyright (c) 2014-2026 Bjoern Kimminich & the OWASP Juice Shop contributors.
 * SPDX-License-Identifier: MIT
 */

import { Component, ElementRef, ViewChild, inject } from '@angular/core'
import { FormsModule } from '@angular/forms'
import { MatButtonModule } from '@angular/material/button'
import { MatIconModule } from '@angular/material/icon'
import { MatTooltipModule } from '@angular/material/tooltip'
import { MatProgressSpinner } from '@angular/material/progress-spinner'
import { AiAssistantService, type AiChatMessage } from '../Services/ai-assistant.service'

@Component({
  selector: 'app-ai-widget',
  templateUrl: './ai-widget.component.html',
  styleUrls: ['./ai-widget.component.scss'],
  imports: [
    FormsModule,
    MatButtonModule,
    MatIconModule,
    MatTooltipModule,
    MatProgressSpinner
  ]
})
export class AiWidgetComponent {
  private readonly aiAssistant = inject(AiAssistantService)

  @ViewChild('messagesEnd') private readonly messagesEnd?: ElementRef<HTMLDivElement>
  @ViewChild('messageInput') private readonly messageInput?: ElementRef<HTMLTextAreaElement>

  open = false
  loading = false
  draft = ''
  error: string | null = null
  messages: AiChatMessage[] = [
    {
      role: 'assistant',
      content: 'Hi! I can help with Juice Shop products and pricing. Ask me anything.'
    }
  ]

  toggle (): void {
    this.open = !this.open
    this.error = null
    if (this.open) {
      setTimeout(() => this.messageInput?.nativeElement.focus(), 0)
    }
  }

  send (): void {
    const content = this.draft.trim()
    if (!content || this.loading) {
      return
    }

    this.messages.push({ role: 'user', content })
    this.draft = ''
    this.loading = true
    this.error = null
    this.scrollToBottom()

    const history = this.messages.slice(1, -1)

    this.aiAssistant.chat(content, history).subscribe({
      next: (response) => {
        this.messages.push({ role: 'assistant', content: response.reply })
        this.loading = false
        this.scrollToBottom()
      },
      error: () => {
        this.loading = false
        this.error = 'Could not reach the AI assistant. Is it running on port 8000?'
        this.scrollToBottom()
      }
    })
  }

  onKeydown (event: KeyboardEvent): void {
    if (event.key === 'Enter' && !event.shiftKey) {
      event.preventDefault()
      this.send()
    }
  }

  private scrollToBottom (): void {
    setTimeout(() => {
      this.messagesEnd?.nativeElement.scrollIntoView({ behavior: 'smooth' })
    }, 0)
  }
}
