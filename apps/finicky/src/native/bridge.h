#ifndef FINICKY_NATIVE_BRIDGE_H
#define FINICKY_NATIVE_BRIDGE_H

#include <stdbool.h>
#include <stdint.h>

void HandleURL(char *url, char *name, char *bundleId, char *path, bool openInBackground);
void QueueWindowDisplay(int32_t launchedByUser);
void ShowConfigWindow(void);
char *GetCurrentConfigPath(void);

#endif
