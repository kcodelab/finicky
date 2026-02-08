#import "window.h"

extern void FinickyWindowShow(void);
extern void FinickyWindowClose(void);
extern void FinickyWindowSendMessage(const char* message);
extern void FinickyWindowSetHTMLContent(const char* content);
extern void FinickyWindowSetFileContent(const char* path, const char* content);
extern void FinickyWindowSetFileContentWithLength(const char* path, const char* content, size_t length);

void ShowWindow(void) {
    FinickyWindowShow();
}

void CloseWindow(void) {
    FinickyWindowClose();
}

void SendMessageToWebView(const char* message) {
    FinickyWindowSendMessage(message);
}

void SetHTMLContent(const char* content) {
    FinickyWindowSetHTMLContent(content);
}

void SetFileContent(const char* path, const char* content) {
    FinickyWindowSetFileContent(path, content);
}

void SetFileContentWithLength(const char* path, const char* content, size_t length) {
    FinickyWindowSetFileContentWithLength(path, content, length);
}
