// browse.h
#ifndef MAIN_H
#define MAIN_H

#include <syslog.h>
#include <stdbool.h>

extern void HandleURL(char *url, char *name, char *bundleId, char *path, bool openInBackground);
extern void QueueWindowDisplay(int launchedByUser);
extern void ShowConfigWindow();
extern char* GetCurrentConfigPath();

void RunApp(bool forceOpenWindow, bool showStatusItem, bool keepRunning);

#endif /* MAIN_H */
