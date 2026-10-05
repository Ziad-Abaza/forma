// Hold-Back Stream Filter (Spec §6.2)

export interface StreamFilterEvent {
  type: 'delta' | 'proposal' | 'metrics' | 'suggestions';
  text?: string;
  payload?: any;
}

export class StreamFilter {
  private buffer = '';
  private insideBlock: 'proposal' | 'metrics' | 'suggestions' | null = null;
  private blockContent = '';

  /**
   * Processes an incoming text chunk from the AI provider stream.
   * Holds back `<action_proposal>`, ```` ```forma:metrics ````, and ```` ```forma:suggestions ````
   * so they do not leak into the visible markdown prose.
   */
  public processChunk(chunk: string): StreamFilterEvent[] {
    const events: StreamFilterEvent[] = [];
    this.buffer += chunk;

    while (this.buffer.length > 0) {
      if (this.insideBlock) {
        // We are currently buffering inside a structured block
        if (this.insideBlock === 'proposal') {
          const closeIndex = this.buffer.indexOf('</action_proposal>');
          if (closeIndex !== -1) {
            this.blockContent += this.buffer.slice(0, closeIndex);
            this.buffer = this.buffer.slice(closeIndex + '</action_proposal>'.length);
            // Finished proposal block
            try {
              const parsed = JSON.parse(this.blockContent.trim());
              events.push({ type: 'proposal', payload: parsed });
            } catch {
              // Ignore malformed proposal
            }
            this.insideBlock = null;
            this.blockContent = '';
            continue;
          } else {
            // Still waiting for closing tag
            this.blockContent += this.buffer;
            this.buffer = '';
            break;
          }
        } else if (this.insideBlock === 'metrics' || this.insideBlock === 'suggestions') {
          const closeIndex = this.buffer.indexOf('```');
          if (closeIndex !== -1) {
            this.blockContent += this.buffer.slice(0, closeIndex);
            this.buffer = this.buffer.slice(closeIndex + 3);
            try {
              const parsed = JSON.parse(this.blockContent.trim());
              if (this.insideBlock === 'metrics') {
                events.push({ type: 'metrics', payload: parsed });
              } else {
                events.push({ type: 'suggestions', payload: parsed });
              }
            } catch {
              // Ignore malformed block
            }
            this.insideBlock = null;
            this.blockContent = '';
            continue;
          } else {
            this.blockContent += this.buffer;
            this.buffer = '';
            break;
          }
        }
      }

      // Check if buffer starts or contains an opening tag
      const openProposalIndex = this.buffer.indexOf('<action_proposal>');
      const openMetricsIndex = this.buffer.indexOf('```forma:metrics');
      const openSuggestionsIndex = this.buffer.indexOf('```forma:suggestions');

      // Find earliest block opener
      const candidates = [
        { type: 'proposal' as const, index: openProposalIndex, len: '<action_proposal>'.length },
        { type: 'metrics' as const, index: openMetricsIndex, len: '```forma:metrics'.length },
        { type: 'suggestions' as const, index: openSuggestionsIndex, len: '```forma:suggestions'.length }
      ].filter(c => c.index !== -1);

      if (candidates.length > 0) {
        candidates.sort((a, b) => a.index - b.index);
        const earliest = candidates[0]!;

        // Flush text preceding the block opener
        if (earliest.index > 0) {
          const safeText = this.buffer.slice(0, earliest.index);
          events.push({ type: 'delta', text: safeText });
        }

        // Enter block mode
        this.insideBlock = earliest.type;
        this.blockContent = '';
        this.buffer = this.buffer.slice(earliest.index + earliest.len);
        continue;
      }

      // If buffer might be part of an opening tag (e.g. starts with '<' or '`')
      const potentialTagIndex = Math.max(this.buffer.lastIndexOf('<'), this.buffer.lastIndexOf('`'));
      if (potentialTagIndex !== -1 && (this.buffer.length - potentialTagIndex) < 25) {
        // Keep potential tag in buffer, emit everything before it
        if (potentialTagIndex > 0) {
          const safeText = this.buffer.slice(0, potentialTagIndex);
          events.push({ type: 'delta', text: safeText });
          this.buffer = this.buffer.slice(potentialTagIndex);
        }
        break; // Wait for next chunk to determine if it's a real tag
      }

      // Safe to flush the whole buffer
      events.push({ type: 'delta', text: this.buffer });
      this.buffer = '';
    }

    return events;
  }

  /**
   * Flushes any remaining buffered text when stream finishes.
   */
  public flush(): StreamFilterEvent[] {
    const events: StreamFilterEvent[] = [];
    if (this.buffer.length > 0 && !this.insideBlock) {
      events.push({ type: 'delta', text: this.buffer });
      this.buffer = '';
    }
    return events;
  }
}
