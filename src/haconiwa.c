#define _GNU_SOURCE
#include <stdio.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <syslog.h>
#include <string.h>
#include <errno.h>

#include "mruby.h"
#include "mruby/string.h"
#include "mruby/hash.h"
#include "mruby/error.h"

#define DONE mrb_gc_arena_restore(mrb, 0);

struct mrbgem_revision {
  const char* gemname;
  const char* revision;
};

const struct mrbgem_revision GEMS[] = {
  #include "REVISIONS.defs"
  {NULL, NULL},
};

static mrb_value mrb_haconiwa_mrgbem_revisions(mrb_state *mrb, mrb_value self)
{
  mrb_value ha = mrb_hash_new(mrb);

  for (int i = 0; GEMS[i].gemname != NULL; ++i) {
    mrb_hash_set(mrb, ha, mrb_str_new_cstr(mrb, GEMS[i].gemname), mrb_str_new_cstr(mrb, GEMS[i].revision));
  }

  return ha;
}

int pivot_root(const char *new_root, const char *put_old){
  return (int)syscall(SYS_pivot_root, new_root, put_old);
}

#define MRB_SYS_ERROR(mrb, msg)                                         \
  do {                                                                  \
    int errno_old = errno;                                              \
    char buf1[1024];                                                    \
    char buf2[2048];                                                    \
    if (strerror_r(errno_old, buf1, 1024) < 0) mrb_sys_fail(mrb, "invalid errno"); \
    if (snprintf(buf2, 2048, "%s - %s", msg, buf1) < 0) mrb_sys_fail(mrb, "failed to construct message"); \
    mrb_sys_fail(mrb, buf2);                                            \
    errno = errno_old;                                                  \
  } while (0)

/* This function is written after lxc/conf.c
   https://github.com/lxc/lxc/blob/3695b24384b71662a1225f6cc25f702667fbbe38/src/lxc/conf.c#L1495 */
static int haconiwa_pivot_root(mrb_state *mrb, const char *rootfs)
{
  int oldroot;
  int newroot = -1, ret = -1;

  oldroot = open("/", O_DIRECTORY | O_RDONLY | O_CLOEXEC);
  if (oldroot < 0) {
    MRB_SYS_ERROR(mrb, "Failed to open old root directory");
    return -1;
  }

  newroot = open(rootfs, O_DIRECTORY | O_RDONLY | O_CLOEXEC);
  if (newroot < 0) {
    MRB_SYS_ERROR(mrb, "Failed to open new root directory");
    goto on_error;
  }

  /* change into new root fs */
  ret = fchdir(newroot);
  if (ret < 0) {
    ret = -1;
    MRB_SYS_ERROR(mrb, "Failed to change to new rootfs");
    goto on_error;
  }

  /* pivot_root into our new root fs */
  ret = pivot_root(".", ".");
  if (ret < 0) {
    ret = -1;
    MRB_SYS_ERROR(mrb, "Failed to pivot_root()");
    goto on_error;
  }

  /* At this point the old-root is mounted on top of our new-root. To
   * unmounted it we must not be chdir'd into it, so escape back to
   * old-root.
   */
  ret = fchdir(oldroot);
  if (ret < 0) {
    ret = -1;
    MRB_SYS_ERROR(mrb, "Failed to enter old root directory");
    goto on_error;
  }

  /* Make oldroot rslave to make sure our umounts don't propagate to the
   * host.
   */
  ret = mount("", ".", "", MS_SLAVE | MS_REC, NULL);
  if (ret < 0) {
    ret = -1;
    MRB_SYS_ERROR(mrb, "Failed to make oldroot rslave");
    goto on_error;
  }

  ret = umount2(".", MNT_DETACH);
  if (ret < 0) {
    ret = -1;
    MRB_SYS_ERROR(mrb, "Failed to detach old root directory");
    goto on_error;
  }

  ret = fchdir(newroot);
  if (ret < 0) {
    ret = -1;
    MRB_SYS_ERROR(mrb, "Failed to re-enter new root directory");
    goto on_error;
  }

  ret = 0;

  syslog(LOG_INFO, "pivot_root(\"%s\") successful", rootfs);

on_error:
  close(oldroot);

  if (newroot >= 0)
    close(newroot);

  return ret;
}

/* TODO: This method will be implemented in mruby-procutil */

static mrb_value mrb_haconiwa_pivot_root_to(mrb_state *mrb, mrb_value self)
{
  char *newroot;
  mrb_get_args(mrb, "z", &newroot);

  if(haconiwa_pivot_root(mrb, newroot) < 0) {
    mrb_sys_fail(mrb, "pivot_root failed!!!");
  }

  return mrb_true_value();
}

void mrb_haconiwa_gem_init(mrb_state *mrb)
{
  struct RClass *haconiwa;
  haconiwa = mrb_define_module(mrb, "Haconiwa");
  mrb_define_class_method(mrb, haconiwa, "mrbgem_revisions", mrb_haconiwa_mrgbem_revisions, MRB_ARGS_NONE());
  mrb_define_class_method(mrb, haconiwa, "pivot_root_to", mrb_haconiwa_pivot_root_to, MRB_ARGS_REQ(1));

  DONE;
}

void mrb_haconiwa_gem_final(mrb_state *mrb)
{
}
