#define _GNU_SOURCE
#include <unistd.h>
#include <sys/syscall.h>
#include <sys/mount.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

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

/* TODO: This method will be implemented in mruby-procutil */
/* This function is written after lxc/conf.c
   https://github.com/lxc/lxc/blob/a467a845443054a9f75d65cf0a73bb4d5ff2ab71/src/lxc/conf.c */
static mrb_value mrb_haconiwa_pivot_root_to(mrb_state *mrb, mrb_value self)
{
  char *newroot;
  int newrootfd = -1, oldrootfd = -1;

  mrb_get_args(mrb, "z", &newroot);

  newrootfd = open(newroot, O_DIRECTORY | O_RDONLY);
  if (newrootfd < 0) {
    mrb_sys_fail(mrb, "open(newroot)");
  }
  if (fchdir(newrootfd) < 0) {
    mrb_sys_fail(mrb, "fchdir(newroot)");
  }

  if (pivot_root(".", "./.gc") < 0) {
    perror("pivot_root");
    mrb_sys_fail(mrb, "Cannot pivot_root!");
  }

  oldrootfd = open("./.gc", O_DIRECTORY | O_RDONLY);
  if (oldrootfd < 0) {
    mrb_sys_fail(mrb, "open(oldrootfd)");
  }
  if (fchdir(oldrootfd) < 0) {
    mrb_sys_fail(mrb, "fchdir(oldroot)");
  }
  if (umount2(".", MNT_DETACH) < 0) {
    mrb_sys_fail(mrb, "umount2");
  }
  if (fchdir(newrootfd) < 0) {
    mrb_sys_fail(mrb, "fchdir(newroot) back");
  }
  close(oldrootfd);
  close(newrootfd);

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
