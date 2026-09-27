#define _GNU_SOURCE
#include <dlfcn.h>
#include <sys/mman.h>
#include <unistd.h>
#include <string.h>
#include <errno.h>
int mprotect(void *addr, size_t len, int prot) {
  int (*real)(void*,size_t,int)=dlsym(RTLD_NEXT,"mprotect");
  int result=real(addr,len,prot);
  if(result==0 || errno!=EACCES || !(prot&PROT_EXEC)) return result;
  int fd=memfd_create("aiko-java-code",MFD_CLOEXEC);
  if(fd<0 || ftruncate(fd,len)<0) { if(fd>=0) close(fd);return -1; }
  void *copy=mmap(NULL,len,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
  if(copy==MAP_FAILED){close(fd);return -1;}
  if(real(addr,len,PROT_READ|PROT_WRITE)!=0){munmap(copy,len);close(fd);return -1;}
  memcpy(copy,addr,len);
  void *mapped=mmap(addr,len,prot,MAP_SHARED|MAP_FIXED,fd,0);
  munmap(copy,len);close(fd);
  return mapped==MAP_FAILED ? -1 : 0;
}
