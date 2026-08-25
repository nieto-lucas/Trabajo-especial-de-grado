typedef unsigned int EFI_STATUS;

EFI_STATUS bad_GetVariable() { /*DETECTA*/
    DataSize = 17;
    gRT->GetVariable(L"Setting1", &guid, 0, &DataSize, buffer1);
    gRT->GetVariable(L"Setting2", &guid, 0, &DataSize, buffer2);
    return 0;
}   

EFI_STATUS good_GetVariable_reasign() { /*NO DETECTA*/   
    DataSize = 17;
    gRT->GetVariable(L"Setting1", &guid, 0, &DataSize, buffer1);
    DataSize = 54;
    gRT->GetVariable(L"Setting2", &guid, 0, &DataSize, buffer2);
    return 0;
}
