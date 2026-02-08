#ifndef WINDOW_H
#define WINDOW_H

#include <stddef.h>

void ShowWindow(void);
void CloseWindow(void);
void SendMessageToWebView(const char* message);
void SetHTMLContent(const char* content);
void SetFileContent(const char* path, const char* content);
void SetFileContentWithLength(const char* path, const char* content, size_t length);

extern void WindowDidClose(void);
extern void WindowIsReady(void);

#endif /* WINDOW_H */
