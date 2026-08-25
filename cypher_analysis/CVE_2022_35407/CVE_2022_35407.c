#include <string.h>
#include <wchar.h>
#include <stdio.h>

struct RT
{
    void (*GetVariable)(const wchar_t*, int*, int*, size_t*, char*);
} gRT_Instance;

struct RT *gRT = &gRT_Instance;

typedef unsigned int EFI_STATUS;

char buffer1[20];
char buffer2[20];
int guid = 0;

void GetVariable(
    const wchar_t *varName, 
    int           *vendorGuid, 
    int           *attributes,
    size_t        *dataSize, 
    char          *data
)
{
    const char *nvramData = 
        "This is a very long string that will take "
        "up more space than the amount specified "
        "in the DataSize variable";
    size_t realSize = strlen(nvramData);

    printf("expected size: %zu \n", *dataSize);
    printf("real size: %zu \n", realSize);

    memcpy(data, nvramData, *dataSize);
    *dataSize = realSize;
}
                            
EFI_STATUS bad_GetVariable() { /*DETECTA*/
    size_t DataSize = 20;
    gRT->GetVariable(L"Setting1", &guid, 0, &DataSize, buffer1);
    gRT->GetVariable(L"Setting2", &guid, 0, &DataSize, buffer2);
    return 0;
}   

EFI_STATUS good_GetVariable_reasign() { /*NO DETECTA*/   
    size_t DataSize = 20;
    gRT->GetVariable(L"Setting1", &guid, 0, &DataSize, buffer1);
    DataSize = 20;
    gRT->GetVariable(L"Setting2", &guid, 0, &DataSize, buffer2);
    return 0;
}

int main()
{
    gRT->GetVariable = GetVariable;
    printf("Good GetVariable: \n");
    good_GetVariable_reasign();
    printf("\n\n");
    printf("Bad GetVariable: \n");
    bad_GetVariable();
    return 0;
}
