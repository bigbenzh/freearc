// to do: ����� ������ �� ������ ("name" ��� "dir/name"),
//        ������������ ������/���������
//        ���������� ".arc", listfiles/-ap/-kb

// ��������� ����� ��� ���������� ������
#undef  ON_CHECK_FAIL
#define ON_CHECK_FAIL()   UnarcQuit()
void UnarcQuit();

// ������ � ��������� ������, �������� ��������� ������ � ���������� �������� ��� �������
#include "ArcStructure.h"
#include "ArcCommand.h"
#include "ArcProcess.h"

// ���������� ����� �� ��������� � ������ ������
void UnarcQuit()
{
  CurrentProcess->quit(FREEARC_ERRCODE_GENERAL, "");
}


// ���� ������ � ������������� ������ � ������� �������, ���������� �����
#include "CUI.h"
CUI UI;


/******************************************************************************
** �������� ��������� *********************************************************
******************************************************************************/

int main (int argc, char *argv[])
{
  UI.DisplayHeader (HEADER1 NAME);
  COMMAND command (argc, argv);    // ���������� �������
  if (command.ok)                  // ���� ������� ��� ������ � ����� ��������� �������
    PROCESS (&command, &UI);       //   ��������� ����������� �������
  printf (command.ok? (command.list_cmd()? "" : "All OK\n") : "Error(s) found\n");
  return command.ok? EXIT_SUCCESS : FREEARC_EXIT_ERROR;
}

